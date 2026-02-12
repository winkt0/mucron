#ifndef MIC_STREAM_PLUGIN_H_
#define MIC_STREAM_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

// Register setup function you’ll call from my_application.cc
void mic_stream_plugin_register(FlBinaryMessenger* messenger);

G_END_DECLS

#endif  // MIC_STREAM_PLUGIN_H_
