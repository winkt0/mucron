import 'dart:math';

class Yin {
  static (int, List<double>) yin(
    List<double> frequencies,
    int maxLag,
    double threshold,
  ) {
    List<double> df = _dfValues(frequencies, maxLag);
    List<double> cmndf = _cmndfValues(df, maxLag);
    int bestLag = _findCmndfArgmin(cmndf, maxLag, threshold);
    return (bestLag, cmndf);
  }

  static double parabolicInterpolation(List<double> cmndf, int lag) {
    final int x0 = max(0, lag - 1);
    final int x2 = min(cmndf.length - 1, lag + 1);
    final double s0 = cmndf[x0];
    final double s1 = cmndf[lag];
    final double s2 = cmndf[x2];
    final double denom = (s0 - 2 * s1 + s2);
    if (denom == 0) return lag.toDouble();
    final double delta = (s0 - s2) / (2 * denom);
    return lag + delta > 0 ? lag + delta : lag.toDouble();
  }
}

List<double> _cmndfValues(List<double> df, int maxLag) {
  List<double> cmndf = List<double>.filled(maxLag + 1, 0.0);
  cmndf[0] = 1.0;
  double sum = 0.0;
  for (int lag = 1; lag <= maxLag; lag++) {
    sum += df[lag];
    cmndf[lag] = lag * df[lag] / (sum == 0.0 ? 1e-10 : sum);
  }
  return cmndf;
}

int _findCmndfArgmin(List<double> cmndf, int maxLag, double threshold) {
  int minLagFound = 0;
  double minValFound = double.maxFinite;
  for (int lag = 2; lag <= maxLag; lag++) {
    if (cmndf[lag] < threshold) {
      while (lag + 1 <= maxLag && cmndf[lag + 1] < cmndf[lag]) {
        lag++;
      }
      return lag;
    }
    if (cmndf[lag] < minValFound) {
      minLagFound = lag;
      minValFound = cmndf[lag];
    }
  }
  return minLagFound;
}

double _df(List<double> f, int lag) {
  double sum = 0;
  int n = f.length;
  for (int i = 0; i < n - lag; i++) {
    sum += pow((f[i] - f[i + lag]), 2);
  }
  return sum;
}

List<double> _dfValues(List<double> frequencies, int maxLag) {
  List<double> dfList = List<double>.filled(maxLag + 1, 0.0, growable: true);
  for (int lag = 1; lag <= maxLag; lag++) {
    dfList[lag] = _df(frequencies, lag);
  }
  dfList[0] = 0.0;
  return dfList;
}

class PyinResult {
  final List<double> frequencies;
  final List<double> times;

  PyinResult(this.frequencies, this.times);
}

class Pyin {
  static PyinResult analyze(
    List<double> samples,
    double sampleRate, {
    int frameSize = 2048,
    int hopSize = 256,
    double f0Min = 50.0,
    double f0Max = 2000.0,
    double yinThreshold = 0.01,
    int maxCandidates = 5,
    double transitionSigmaHz =
        50.0, // smoothness of pitch transitions - does not make much of a difference when only considering voiced
  }) {
    final frames = _frameSignal(
      samples,
      frameSize,
      hopSize,
      window: _hannWindow,
    );
    final numFrames = frames.length;
    final times = List<double>.generate(
      numFrames,
      (i) => ((i * hopSize + frameSize / 2) / sampleRate),
    );

    final maxTau = (sampleRate / f0Min).floor();
    final minTau = max(2, (sampleRate / f0Max).floor());
    final tauLimit = min(maxTau, frameSize);
    final allCandidates = List<List<_Candidate>>.generate(numFrames, (_) => []);

    for (var fi = 0; fi < numFrames; fi++) {
      _getCandidates(
        frames,
        fi,
        tauLimit,
        minTau,
        yinThreshold,
        sampleRate,
        maxCandidates,
        allCandidates,
      );
    }
    const double alpha = 15.0;
    List<List<double>> logObs = _buildObservationProbs(
      numFrames,
      allCandidates,
      alpha,
    );
    final sigma = transitionSigmaHz;
    final backPointers = List<List<int?>>.generate(numFrames, (i) => []);
    final dp = List<List<double>>.generate(numFrames, (i) => []);
    dp[0] = List<double>.from(logObs[0]);
    backPointers[0] = List<int?>.filled(dp[0].length, null);

    for (var frame = 1; frame < numFrames; frame++) {
      _findBestUsingViterbi(
        dp,
        frame,
        logObs,
        backPointers,
        allCandidates,
        sigma,
      );
    }

    int bestFinalIndex = _backtrackBestIndex(dp);

    final statePath = List<int>.filled(numFrames, 0);
    statePath[numFrames - 1] = bestFinalIndex;
    for (var frame = numFrames - 1; frame > 0; frame--) {
      final bp = backPointers[frame][statePath[frame]];
      statePath[frame - 1] = bp ?? 0;
    }

    final f0 = List<double>.filled(numFrames, 0);

    for (var frame = 0; frame < numFrames; frame++) {
      final st = statePath[frame];
      f0[frame] = allCandidates[frame][st].freq;
    }

    return PyinResult(f0, times);
  }

  static int _backtrackBestIndex(List<List<double>> dp) {
    var bestFinalIndex = 0;
    var bestFinalScore = dp.last[0];
    for (var i = 1; i < dp.last.length; i++) {
      if (dp.last[i] > bestFinalScore) {
        bestFinalScore = dp.last[i];
        bestFinalIndex = i;
      }
    }
    return bestFinalIndex;
  }

  static void _findBestUsingViterbi(
    List<List<double>> dp,
    int frame,
    List<List<double>> logObs,
    List<List<int?>> backPointers,
    List<List<_Candidate>> allCandidates,
    double sigma,
  ) {
    final prevLen = dp[frame - 1].length;
    final curLen = logObs[frame].length;
    dp[frame] = List<double>.filled(curLen, double.negativeInfinity);
    backPointers[frame] = List<int?>.filled(curLen, null);

    for (var curCandidate = 0; curCandidate < curLen; curCandidate++) {
      double bestScore = double.negativeInfinity;
      int? bestPrev;
      for (var prevCandidate = 0; prevCandidate < prevLen; prevCandidate++) {
        final prevScore = dp[frame - 1][prevCandidate];
        double logTrans;
        final prevFreq = allCandidates[frame - 1][prevCandidate].freq;
        final curFreq = (curCandidate < allCandidates[frame].length)
            ? allCandidates[frame][curCandidate].freq
            : allCandidates[frame - 1][prevCandidate].freq;
        final df = curFreq - prevFreq;
        logTrans = -(df * df) / (2 * sigma * sigma);
        final candScore = prevScore + logTrans + logObs[frame][curCandidate];
        if (candScore > bestScore) {
          bestScore = candScore;
          bestPrev = prevCandidate;
        }
      }
      dp[frame][curCandidate] = bestScore;
      backPointers[frame][curCandidate] = bestPrev;
    }
  }

  static List<List<double>> _buildObservationProbs(
    int numFrames,
    List<List<_Candidate>> allCandidates,
    double alpha,
  ) {
    final logObs = List<List<double>>.generate(numFrames, (i) {
      final cand = allCandidates[i];
      final List<double> l = List<double>.filled(
        cand.length,
        double.negativeInfinity,
      );
      for (var j = 0; j < cand.length; j++) {
        final cm = cand[j].cmnd;
        final voicedLike = exp(-alpha * cm);
        final p = voicedLike.clamp(1e-9, 1.0);
        l[j] = log(p);
      }
      return l;
    });
    return logObs;
  }

  static void _getCandidates(
    List<List<double>> frames,
    int fi,
    int tauLimit,
    int minTau,
    double yinThreshold,
    double sampleRate,
    int maxCandidates,
    List<List<_Candidate>> allCandidates,
  ) {
    final frame = frames[fi];
    final d = _dfValues(frame, tauLimit);
    final cmnd = _cmndfValues(d, tauLimit);
    final candidates = _getCandidatesFromCMND(
      cmnd,
      minTau,
      tauLimit,
      yinThreshold,
    );
    final refined = <_Candidate>[];
    for (int tau in candidates) {
      final interpTau = Yin.parabolicInterpolation(cmnd, tau);
      final refinedTau = interpTau.clamp(
        minTau.toDouble(),
        tauLimit.toDouble(),
      );
      final freq = sampleRate / refinedTau;
      refined.add(_Candidate(freq, cmnd[tau], refinedTau));
    }
    refined.sort((a, b) => a.cmnd.compareTo(b.cmnd));
    if (refined.length > maxCandidates) {
      refined.removeRange(maxCandidates, refined.length);
    }
    allCandidates[fi] = refined;
  }

  static List<List<double>> _frameSignal(
    List<double> samples,
    int frameSize,
    int hopSize, {
    List<double> Function(int)? window,
  }) {
    final win = (window != null)
        ? window(frameSize)
        : List<double>.filled(frameSize, 1.0);
    final frames = <List<double>>[];
    for (var start = 0; start + frameSize <= samples.length; start += hopSize) {
      final frame = List<double>.filled(frameSize, 0.0);
      for (var i = 0; i < frameSize; i++) {
        frame[i] = samples[start + i]; // * win[i];
      }
      frames.add(frame);
    }
    return frames;
  }

  static List<double> _hannWindow(int size) {
    final w = List<double>.filled(size, 0.0);
    for (var i = 0; i < size; i++) {
      w[i] = 0.5 * (1 - cos(2 * pi * i / (size - 1)));
    }
    return w;
  }

  static List<int> _getCandidatesFromCMND(
    List<double> cmnd,
    int minTau,
    int maxTau,
    double threshold,
  ) {
    final candidates = <int>[];
    for (var tau = minTau; tau <= maxTau - 1; tau++) {
      final val = cmnd[tau];
      if (val < threshold) {
        if (val <= cmnd[tau - 1] && val <= cmnd[tau + 1]) {
          candidates.add(tau);
        } else {
          int left = tau;
          while (left > minTau && cmnd[left - 1] < cmnd[left]) {
            left--;
          }
          int right = tau;
          while (right < maxTau && cmnd[right + 1] < cmnd[right]) {
            right++;
          }
          final minPos = (cmnd[left] < cmnd[right]) ? left : right;
          if (!candidates.contains(minPos)) candidates.add(minPos);
        }
      }
    }
    if (candidates.isEmpty) {
      final indices = List<int>.generate(
        maxTau - minTau + 1,
        (i) => i + minTau,
      );
      indices.sort((a, b) => cmnd[a].compareTo(cmnd[b]));
      final take = min(3, indices.length);
      for (var i = 0; i < take; i++) {
        candidates.add(indices[i]);
      }
    }
    return candidates;
  }
}

class _Candidate {
  final double freq;
  final double cmnd;
  final double tau;
  _Candidate(this.freq, this.cmnd, this.tau);
}
