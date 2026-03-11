extern "C" {
    const char* ManyMouse_DeviceName(unsigned int index) { return "Mouse"; }
    const char* ManyMouse_DriverName() { return "Driver"; }
    int ManyMouse_Init() { return 0; }
    int ManyMouse_PollEvent(void* event) { return 0; }
    void ManyMouse_Quit() {}

    void SDL_CDClose(void* cdrom) {}
    void SDL_CDEject(void* cdrom) {}
    const char* SDL_CDName(int drive) { return "CD"; }
    int SDL_CDNumDrives() { return 0; }
    void* SDL_CDOpen(int drive) { return 0; }
    void SDL_CDPause(void* cdrom) {}
    int SDL_CDPlayTracks(void* cdrom, int start_track, int start_frame, int ntracks, int nframes) { return 0; }
    void SDL_CDResume(void* cdrom) {}
    int SDL_CDStatus(void* cdrom) { return 0; }
    void SDL_CDStop(void* cdrom) {}
    int SDL_CDPlay(void*, int, int) { return 0; }

    void YM7128B_ChipIdeal_Ctor(void**) {}
    void YM7128B_ChipIdeal_Dtor(void**) {}
    void YM7128B_ChipIdeal_Process(void**, float**, int) {}
    void YM7128B_ChipIdeal_Reset(void**) {}
    void YM7128B_ChipIdeal_Setup(void**, int, int) {}
    void YM7128B_ChipIdeal_Start(void**) {}
    void YM7128B_ChipIdeal_Stop(void**) {}
    void YM7128B_ChipIdeal_Write(void**, int, int) {}

    void speex_resampler_destroy(void*) {}
    void speex_resampler_get_ratio(void*, void*, void*) {}
    void* speex_resampler_init(int, int, int, int*, int*) { return 0; }
    void speex_resampler_process_interleaved_float(void*, float*, unsigned int*, float*, unsigned int*) {}
    void speex_resampler_reset_mem(void*) {}
    void speex_resampler_set_rate(void*, int, int) {}
    void speex_resampler_skip_zeros(void*) {}

    int wai_getExecutablePath(char*, int, int*) { return 0; }

    void* __Sound_DecoderFunctions_OPUS = 0;
}

void boxer_updateVolumes() {}

enum OplMode { OPL_NONE };
class Section;
void OPL_Init(Section*, OplMode) {}
void OPL_ShutDown(Section*) {}

void ReelMagic_Init(Section*) {}
void REELMAGIC_MaybeCreateFmpdrvExecutable() {}

struct Fraction { int num; int den; };
enum class IntegerScalingMode { None };
enum class InterpolationMode { None };
enum class RenderingBackend { None };
enum class MouseHint { None };

void E_Exit(char const*, ...) {}
void GFX_CalcViewport(int, int, int, int, Fraction const&) {}
void GFX_GetCanvasSize() {}
IntegerScalingMode GFX_GetIntegerScalingMode() { return IntegerScalingMode::None; }
InterpolationMode GFX_GetInterpolationMode() { return InterpolationMode::None; }
RenderingBackend GFX_GetRenderingBackend() { return RenderingBackend::None; }
bool GFX_HaveDesktopEnvironment() { return false; }
void GFX_RefreshTitle() {}
void GFX_SetIntegerScalingMode(IntegerScalingMode) {}
void GFX_SetMouseCapture(bool) {}
void GFX_SetMouseHint(MouseHint) {}
void GFX_SetMouseRawInput(bool) {}
void GFX_SetMouseVisibility(bool) {}

void MAPPER_AutoTypeStopImmediately() {}
void OpenCaptureFile(char const*, char const*) {}

enum ZMBV_FORMAT { None };
class VideoCodec {
public:
    VideoCodec();
    void CompressLines(int, unsigned char const**);
    void FinishCompressFrame();
    void FinishVideo();
    int NeededSize(int, int, ZMBV_FORMAT);
    void PrepareCompressFrame(int, ZMBV_FORMAT, unsigned char const*, unsigned char*, unsigned int);
    void SetupCompress(int, int);
};
VideoCodec::VideoCodec() {}
void VideoCodec::CompressLines(int, unsigned char const**) {}
void VideoCodec::FinishCompressFrame() {}
void VideoCodec::FinishVideo() {}
int VideoCodec::NeededSize(int, int, ZMBV_FORMAT) { return 0; }
void VideoCodec::PrepareCompressFrame(int, ZMBV_FORMAT, unsigned char const*, unsigned char*, unsigned int) {}
void VideoCodec::SetupCompress(int, int) {}

#include "DOSBox-Staging/subprojects/iir1-1.9.3/iir/Biquad.cpp"
#include "DOSBox-Staging/subprojects/iir1-1.9.3/iir/Cascade.cpp"
#include "DOSBox-Staging/subprojects/iir1-1.9.3/iir/Butterworth.cpp"
#include "DOSBox-Staging/subprojects/iir1-1.9.3/iir/PoleFilter.cpp"
#include "DOSBox-Staging/subprojects/iir1-1.9.3/iir/RBJ.cpp"
#include "DOSBox-Staging/subprojects/iir1-1.9.3/iir/ChebyshevI.cpp"
#include "DOSBox-Staging/subprojects/iir1-1.9.3/iir/ChebyshevII.cpp"
#include "DOSBox-Staging/subprojects/iir1-1.9.3/iir/Custom.cpp"
