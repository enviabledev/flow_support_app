import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isRecording = false;
  bool _isPhotoMode = true;
  FlashMode _flashMode = FlashMode.off;
  List<AssetEntity> _recentPhotos = [];
  final Set<int> _selectedIndices = {};
  bool _cameraReady = false;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _requestPermissionsAndInit();
  }

  Future<void> _requestPermissionsAndInit() async {
    // Permissions should already be granted from the login flow.
    // If not, request camera specifically here as a fallback.
    if (!await Permission.camera.isGranted) {
      await Permission.camera.request();
    }
    _initCamera();
    _loadRecentPhotos();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _setupCamera(_selectedCameraIndex);
  }

  Future<void> _setupCamera(int index) async {
    final old = _controller;
    _controller = null;
    if (old != null) await old.dispose();

    final c = CameraController(
      _cameras[index],
      ResolutionPreset.max,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      await c.setFlashMode(_flashMode);
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      _controller = c;
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _loadRecentPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) return;

    // Get ALL images from every source (camera, WhatsApp, downloads, screenshots)
    // sorted by creation date descending so newest appear first
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (albums.isEmpty) return;

    // Use the "All" album which aggregates everything across all folders
    final allAlbum = albums.firstWhere((a) => a.isAll, orElse: () => albums[0]);
    final recent = await allAlbum.getAssetListPaged(page: 0, size: 30);
    if (mounted) setState(() => _recentPhotos = recent);
  }

  void _flipCamera() async {
    if (_cameras.length < 2 || _isFlipping) return;
    _isFlipping = true;
    setState(() => _cameraReady = false);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCamera(_selectedCameraIndex);
    _isFlipping = false;
  }

  void _toggleFlash() {
    setState(() {
      _flashMode = _flashMode == FlashMode.off
          ? FlashMode.auto
          : _flashMode == FlashMode.auto
              ? FlashMode.always
              : FlashMode.off;
    });
    _controller?.setFlashMode(_flashMode);
  }

  IconData get _flashIcon => switch (_flashMode) {
        FlashMode.off => Icons.flash_off,
        FlashMode.auto => Icons.flash_auto,
        FlashMode.always => Icons.flash_on,
        _ => Icons.flash_off,
      };

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture) return;
    try {
      final image = await _controller!.takePicture();
      if (mounted) Navigator.pop(context, {'files': [File(image.path)], 'type': 'image'});
    } catch (e) {
      debugPrint('Take photo error: $e');
    }
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isRecording) {
      try {
        final video = await _controller!.stopVideoRecording();
        setState(() => _isRecording = false);
        if (mounted) Navigator.pop(context, {'files': [File(video.path)], 'type': 'video'});
      } catch (_) {
        setState(() => _isRecording = false);
      }
    } else {
      try {
        await _controller!.startVideoRecording();
        setState(() => _isRecording = true);
      } catch (e) {
        debugPrint('Start recording error: $e');
      }
    }
  }

  void _onShutterTap() => _isPhotoMode ? _takePhoto() : _toggleRecording();

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _sendSelected() async {
    if (_selectedIndices.isEmpty) return;
    final files = <File>[];
    for (final i in _selectedIndices) {
      final f = await _recentPhotos[i].file;
      if (f != null) files.add(f);
    }
    if (files.isNotEmpty && mounted) Navigator.pop(context, {'files': files, 'type': 'image'});
  }

  Future<void> _openFullGallery() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty && mounted) {
      Navigator.pop(context, {'files': images.map((x) => File(x.path)).toList(), 'type': 'image'});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: Camera preview — fills entire screen
          if (_cameraReady && _controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.previewSize?.height ?? 1,
                  height: _controller!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          else
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

          // LAYER 2: X close button
          Positioned(
            top: pad.top + 8, left: 12,
            child: _circleButton(Icons.close, () => Navigator.pop(context)),
          ),

          // LAYER 3: Flash toggle
          Positioned(
            top: pad.top + 8, right: 12,
            child: _circleButton(_flashIcon, _toggleFlash),
          ),

          // LAYER 4: Recording indicator
          if (_isRecording)
            Positioned(
              top: pad.top + 16, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(16)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, color: Colors.white, size: 10),
                    SizedBox(width: 6),
                    Text('REC', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),

          // LAYER 5: Bottom overlay — thumbnails, controls, mode
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thumbnail strip (only photo mode)
                if (_isPhotoMode && _recentPhotos.isNotEmpty)
                  GestureDetector(
                    onVerticalDragEnd: (d) {
                      if (d.velocity.pixelsPerSecond.dy < -300) _openFullGallery();
                    },
                    child: SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        itemCount: _recentPhotos.length,
                        itemBuilder: (_, i) {
                          final selected = _selectedIndices.contains(i);
                          return GestureDetector(
                            onTap: () => _toggleSelection(i),
                            child: SizedBox(
                              width: 72, height: 72,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AssetEntityImage(
                                    _recentPhotos[i],
                                    isOriginal: false,
                                    thumbnailSize: const ThumbnailSize(200, 200),
                                    fit: BoxFit.cover,
                                  ),
                                  if (selected)
                                    Container(
                                      color: Colors.black38,
                                      child: Center(
                                        child: Container(
                                          width: 28, height: 28,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00A884),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Drag handle
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
                ),

                // Controls row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _controlButton(Icons.photo_library_outlined, _openFullGallery, rounded: true),
                      _controlButton(_flashIcon, _toggleFlash),
                      // Shutter
                      GestureDetector(
                        onTap: _onShutterTap,
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _isRecording ? Colors.red : Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: _isRecording ? Colors.red : Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 48),
                      _controlButton(Icons.cameraswitch_outlined, _flipCamera, circle: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Mode selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _modeLabel('Video', !_isPhotoMode, () => setState(() => _isPhotoMode = false)),
                    const SizedBox(width: 16),
                    _modeLabel('Photo', _isPhotoMode, () => setState(() => _isPhotoMode = true)),
                  ],
                ),
                SizedBox(height: pad.bottom + 12),
              ],
            ),
          ),

          // LAYER 6: Green send FAB
          if (_selectedIndices.isNotEmpty)
            Positioned(
              bottom: 200 + pad.bottom,
              right: 16,
              child: GestureDetector(
                onTap: _sendSelected,
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A884),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 28),
                      Positioned(
                        top: 4, right: 4,
                        child: Container(
                          width: 20, height: 20,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Center(child: Text('${_selectedIndices.length}',
                            style: const TextStyle(color: Color(0xFF00A884), fontSize: 11, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onTap, {bool rounded = false, bool circle = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: circle ? null : (rounded ? BorderRadius.circular(12) : null),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _modeLabel(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(
          color: active ? Colors.white : Colors.white54,
          fontSize: 15, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }
}
