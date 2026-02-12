#include "mic_stream_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <glib-object.h>
#include <glib.h>
#include <cstring>
#include <vector>
#include <mutex>
#include <atomic>

#define MINIAUDIO_IMPLEMENTATION
#include "third_party/miniaudio.h"

// ---------- Config ----------
static const int kSampleRate = 44100;
static const int kChannels = 1;
static const int kFrameSize = 1024; // samples per event
static const char *kChannelName = "com.example.mic_stream/audio";

// ---------- State ----------
struct MicStreamState
{
    FlEventChannel *channel = nullptr;
    bool listening = false;

    ma_context context{};
    ma_device device{};
    bool running = false;

    std::vector<float> fifo;
    std::mutex fifo_mutex;

    guint drain_source_id = 0; // main-thread GLib source id
};

// Forward decl
static void stop_device(MicStreamState *s);

static gboolean drain_and_send_periodic(gpointer user_data)
{
    MicStreamState *s = reinterpret_cast<MicStreamState *>(user_data);
    if (!s || !s->listening)
        return G_SOURCE_CONTINUE;

    while (true)
    {
        std::vector<float> chunk;
        {
            std::lock_guard<std::mutex> lock(s->fifo_mutex);
            if (s->fifo.size() < static_cast<size_t>(kFrameSize))
                break;
            chunk.assign(s->fifo.begin(), s->fifo.begin() + kFrameSize);
            s->fifo.erase(s->fifo.begin(), s->fifo.begin() + kFrameSize);
        }
        // Build payload
        const uint8_t *bytes = reinterpret_cast<const uint8_t *>(chunk.data());
        const size_t nbytes = chunk.size() * sizeof(float);
        g_autoptr(GBytes) payload = g_bytes_new(bytes, nbytes);
        g_autoptr(FlValue) value = fl_value_new_uint8_list_from_bytes(payload);

        // Send ON THE MAIN THREAD (we are already on it)
        g_autoptr(GError) error = nullptr;
        if (!fl_event_channel_send(s->channel, value, nullptr, &error))
        {
            g_warning("mic_stream send failed: %s", error ? error->message : "unknown");
            break; // bail this tick; try next tick
        }
    }
    return G_SOURCE_CONTINUE; // keep the periodic source alive
}

// miniaudio callback: audio thread
static void capture_callback(ma_device *device, void *, const void *input, ma_uint32 frameCount)
{
    MicStreamState *s = reinterpret_cast<MicStreamState *>(device->pUserData);
    if (!s || !input)
        return;
    const float *in = reinterpret_cast<const float *>(input);
    const size_t samples = static_cast<size_t>(frameCount) * kChannels;

    std::lock_guard<std::mutex> lock(s->fifo_mutex);
    s->fifo.insert(s->fifo.end(), in, in + samples);
}

// Start device (called on listen)
static bool start_device(MicStreamState *s)
{
    if (s->running)
        return true;

    ma_context_config ctxCfg = ma_context_config_init();
    if (ma_context_init(nullptr, 0, &ctxCfg, &s->context) != MA_SUCCESS)
    {
        return false;
    }

    ma_device_config cfg = ma_device_config_init(ma_device_type_capture);
    cfg.sampleRate = kSampleRate;
    cfg.capture.format = ma_format_f32;
    cfg.capture.channels = kChannels;
    cfg.dataCallback = capture_callback;
    cfg.pUserData = s;

    if (ma_device_init(&s->context, &cfg, &s->device) != MA_SUCCESS)
    {
        ma_context_uninit(&s->context);
        return false;
    }

    if (ma_device_start(&s->device) != MA_SUCCESS)
    {
        ma_device_uninit(&s->device);
        ma_context_uninit(&s->context);
        return false;
    }

    s->running = true;
    return true;
}

static void stop_device(MicStreamState *s)
{
    if (!s || !s->running)
        return;
    s->running = false;
    ma_device_stop(&s->device);
    ma_device_uninit(&s->device);
    ma_context_uninit(&s->context);
    std::lock_guard<std::mutex> lock(s->fifo_mutex);
    s->fifo.clear();
}

// ---------- Stream handlers ----------
static FlMethodErrorResponse *on_listen(FlEventChannel *channel, FlValue *, gpointer user_data)
{
    MicStreamState *s = reinterpret_cast<MicStreamState *>(user_data);
    s->channel = channel;
    s->listening = true;

    if (!start_device(s))
    {
        s->listening = false;
        return fl_method_error_response_new("START_FAILED", "Failed to start audio capture", nullptr);
    }

    // Start periodic drainer on the MAIN THREAD (we are on it)
    if (s->drain_source_id == 0)
    {
        // Every ~5 ms; adjust if you want fewer UI updates (e.g. 10–15 ms)
        s->drain_source_id = g_timeout_add_full(G_PRIORITY_DEFAULT, 5,
                                                drain_and_send_periodic, s, nullptr);
    }
    return nullptr;
}

static FlMethodErrorResponse *on_cancel(FlEventChannel *, FlValue *, gpointer user_data)
{
    MicStreamState *s = reinterpret_cast<MicStreamState *>(user_data);
    s->listening = false;

    // Stop periodic drainer on main thread
    if (s->drain_source_id != 0)
    {
        g_source_remove(s->drain_source_id);
        s->drain_source_id = 0;
    }

    stop_device(s);
    {
        std::lock_guard<std::mutex> lock(s->fifo_mutex);
        s->fifo.clear();
    }
    return nullptr;
}

void mic_stream_plugin_register(FlBinaryMessenger *messenger)
{
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

    // Allocate shared state for this channel
    MicStreamState *state = new MicStreamState();

    // Create the EventChannel
    FlEventChannel *channel =
        fl_event_channel_new(messenger, kChannelName, FL_METHOD_CODEC(codec));

    // Hook stream handlers; destroy callback cleans up everything
    fl_event_channel_set_stream_handlers(
        channel,
        on_listen, // FlMethodErrorResponse* (*)(FlEventChannel*, FlValue*, gpointer)
        on_cancel, // FlMethodErrorResponse* (*)(FlEventChannel*, FlValue*, gpointer)
        state,     // user_data passed to handlers
        [](gpointer user_data)
        {
            auto *s = reinterpret_cast<MicStreamState *>(user_data);
            // Stop periodic drainer if running
            if (s->drain_source_id != 0)
            {
                g_source_remove(s->drain_source_id);
                s->drain_source_id = 0;
            }
            // Stop audio + clear buffers
            stop_device(s);
            {
                std::lock_guard<std::mutex> lock(s->fifo_mutex);
                s->fifo.clear();
            }
            delete s;
        });
}
