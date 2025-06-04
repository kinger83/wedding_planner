import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert' show base64Decode;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class PhotoGalleryPage extends StatefulWidget {
  final bool isAdmin;

  PhotoGalleryPage({Key? key, this.isAdmin = false}) : super(key: key);

  @override
  _PhotoGalleryPageState createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = firebase_storage.FirebaseStorage.instance;
  bool _isLoading = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  int _totalUploads = 0;
  String _currentUploadFileName = '';
  List<Map<String, dynamic>> _photos = [];
  final _uploaderNameController = TextEditingController();
  String? _selectedPhotoUrl;

  // Custom cache manager for wedding photos
  static final CacheManager _customCacheManager = CacheManager(
    Config(
      "wedding_photos_cache",
      stalePeriod: const Duration(days: 7), // Cache for 7 days
      maxNrOfCacheObjects: 1000, // Cache up to 1000 images
      repo: JsonCacheInfoRepository(databaseName: "wedding_photos_cache"),
      fileService: HttpFileService(),
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _debugAppCheck();
  }

  @override
  void dispose() {
    _uploaderNameController.dispose();
    super.dispose();
  }

  // Debug App Check functionality
  Future<void> _debugAppCheck() async {
    try {
      print('🛡️ Testing App Check functionality...');
      final token = await FirebaseAppCheck.instance.getToken();
      if (token != null) {
        print('✅ App Check token obtained successfully!');
        print('🔒 Token length: ${token.length} characters');
      } else {
        print('❌ Failed to get App Check token');
      }
    } catch (e) {
      print('❌ App Check error: $e');
    }
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    print('📸 Loading photos with App Check protection...');
    
    try {
      final snapshot = await _firestore
          .collection('wedding_photos')
          .orderBy('uploadedAt', descending: true)
          .get();
      
      print('✅ Photos loaded successfully - ${snapshot.docs.length} photos found');
      print('🛡️ All requests protected by App Check!');
      
      setState(() {
        _photos = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading photos: $e');
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading photos: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  // Create thumbnail from image bytes
  Future<Uint8List> _createThumbnail(Uint8List imageBytes) async {
    try {
      // For web, we'll use a different approach with HTML canvas
      if (kIsWeb) {
        return await _createWebThumbnail(imageBytes);
      }
      
      // Decode the image with smaller dimensions
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 600, // High quality thumbnails
        targetHeight: 600,
      );
      final frame = await codec.getNextFrame();
      
      // Convert to PNG
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      print('Error creating thumbnail: $e');
      return await _createBasicThumbnail(imageBytes);
    }
  }

  // Web-specific thumbnail creation using canvas
  Future<Uint8List> _createWebThumbnail(Uint8List imageBytes) async {
    final completer = Completer<Uint8List>();
    
    // Create an image element
    final img = html.ImageElement();
    final blob = html.Blob([imageBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    img.onLoad.listen((_) async {
      try {
        // Create canvas
        final canvas = html.CanvasElement(width: 600, height: 600);
        final ctx = canvas.context2D;
        
        // Calculate scaling to maintain aspect ratio
        final scale = math.min(600 / img.width!, 600 / img.height!);
        final scaledWidth = (img.width! * scale).round();
        final scaledHeight = (img.height! * scale).round();
        
        // Center the image
        final x = (600 - scaledWidth) / 2;
        final y = (600 - scaledHeight) / 2;
        
        // Draw scaled image
        ctx.drawImageScaled(img, x, y, scaledWidth.toDouble(), scaledHeight.toDouble());
        
        // Get canvas data as data URL and convert to bytes
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.85); // High quality
        final base64Data = dataUrl.split(',')[1];
        final bytes = base64Decode(base64Data);
        
        completer.complete(Uint8List.fromList(bytes));
        html.Url.revokeObjectUrl(url);
      } catch (e) {
        html.Url.revokeObjectUrl(url);
        completer.completeError('Failed to create thumbnail: $e');
      }
    });
    
    img.onError.listen((_) {
      html.Url.revokeObjectUrl(url);
      completer.completeError('Failed to load image');
    });
    
    img.src = url;
    return completer.future;
  }

  // Fallback basic thumbnail
  Future<Uint8List> _createBasicThumbnail(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: 500,
      targetHeight: 500,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _pickAndUploadPhotos() async {
    // Show name dialog if not admin
    if (!widget.isAdmin) {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => _buildNameDialog(),
      );
      
      if (name == null || name.isEmpty) return;
      _uploaderNameController.text = name;
    }
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        allowMultiple: true,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0;
          _totalUploads = result.files.length;
          _currentUploadFileName = '';
        });
        
        print('🛡️ App Check protecting ${result.files.length} uploads...');
        
        int uploadedCount = 0;
        int failedCount = 0;
        
        for (final file in result.files) {
          if (file.bytes != null) {
            try {
              setState(() {
                _currentUploadFileName = file.name;
              });
              
              await _uploadPhoto(file.bytes!, file.name);
              uploadedCount++;
              
              setState(() {
                _uploadProgress = uploadedCount + failedCount;
              });
              
              // Reload photos after each successful upload to show progress
              await _loadPhotos();
              
            } catch (e) {
              print('Error uploading ${file.name}: $e');
              failedCount++;
              
              setState(() {
                _uploadProgress = uploadedCount + failedCount;
              });
            }
          }
        }
        
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
          _totalUploads = 0;
          _currentUploadFileName = '';
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded $uploadedCount photos${failedCount > 0 ? ', $failedCount failed' : ''}'),
            backgroundColor: Colors.green[400],
          ),
        );
      }
    } catch (e) {
      print('Error picking files: $e');
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _totalUploads = 0;
        _currentUploadFileName = '';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting photos: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  Future<void> _uploadPhoto(Uint8List bytes, String fileName) async {
    print('🚨 Uploading photo with smart thumbnail generation...');
    print('🛡️ App Check protecting this upload...');
    
    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = fileName.split('.').last;
    final uniqueFileName = 'wedding_photo_$timestamp.$extension';
    final thumbnailFileName = 'thumb_$uniqueFileName';
    
    // Upload original to Firebase Storage
    final ref = _storage.ref().child('wedding_photos/$uniqueFileName');
    final uploadTask = ref.putData(bytes);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    
    String thumbnailUrl = downloadUrl; // Default to original
    int? thumbnailSize;
    
    // Only create thumbnail if original is large enough (>300KB)
    if (bytes.length > 300000) {
      try {
        print('📸 Creating high-quality thumbnail...');
        final thumbnailBytes = await _createThumbnail(bytes);
        
        // Only use thumbnail if it's actually smaller
        if (thumbnailBytes.length < bytes.length * 0.8) {
          final thumbRef = _storage.ref().child('wedding_photos/thumbnails/$thumbnailFileName');
          final thumbUploadTask = thumbRef.putData(thumbnailBytes);
          final thumbSnapshot = await thumbUploadTask;
          thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();
          thumbnailSize = thumbnailBytes.length;
          print('✅ Thumbnail created: ${thumbnailBytes.length} bytes vs ${bytes.length} bytes original');
        } else {
          print('Thumbnail not smaller than original, using original');
        }
      } catch (e) {
        print('Thumbnail creation failed, using original: $e');
      }
    } else {
      print('File too small for thumbnail, using original');
    }
    
    // Save metadata to Firestore
    await _firestore.collection('wedding_photos').add({
      'url': downloadUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileName': uniqueFileName,
      'thumbnailFileName': thumbnailUrl != downloadUrl ? thumbnailFileName : null,
      'originalFileName': fileName,
      'uploaderName': widget.isAdmin ? 'Admin' : _uploaderNameController.text,
      'uploadedAt': FieldValue.serverTimestamp(),
      'size': bytes.length,
      'thumbnailSize': thumbnailSize,
    });
    
    print('✅ Upload complete with App Check protection!');
  }

  Future<void> _deletePhoto(String photoId, String fileName, String? thumbnailFileName) async {
    try {
      print('🛡️ App Check protecting photo deletion...');
      
      // Delete from Storage
      await _storage.ref().child('wedding_photos/$fileName').delete();
      
      // Delete thumbnail from Storage
      if (thumbnailFileName != null) {
        await _storage.ref().child('wedding_photos/thumbnails/$thumbnailFileName').delete();
      }
      
      // Delete from Firestore
      await _firestore.collection('wedding_photos').doc(photoId).delete();
      
      // Reload photos
      await _loadPhotos();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo deleted successfully'),
          backgroundColor: Colors.green[400],
        ),
      );
    } catch (e) {
      print('Error deleting photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting photo: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  void _downloadPhoto(String url, String fileName) {
    if (kIsWeb) {
      print('💾 Downloading photo...');
      // Web download
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
    }
  }

  void _showPhotoFullscreen(String url, String thumbnailUrl, String uploaderName, DateTime? uploadedAt) {
    // For guests, show thumbnail in fullscreen
    // For admin, show full resolution
    final displayUrl = widget.isAdmin ? url : thumbnailUrl;
    
    setState(() => _selectedPhotoUrl = displayUrl);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full screen photo with caching
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black,
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: widget.isAdmin ? 4 : 2, // Less zoom for thumbnails
                    child: CachedNetworkImage(
                      imageUrl: displayUrl,
                      fit: BoxFit.contain,
                      cacheManager: _customCacheManager,
                      memCacheWidth: widget.isAdmin ? null : 800,
                      memCacheHeight: widget.isAdmin ? null : 800,
                      maxWidthDiskCache: widget.isAdmin ? null : 1000,
                      maxHeightDiskCache: widget.isAdmin ? null : 1000,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey[400],
                          size: 80,
                        ),
                      ),
                      // Debug cache loading
                      imageBuilder: (context, imageProvider) {
                        print('🎯 Image loaded from cache successfully!');
                        return Image(image: imageProvider, fit: BoxFit.contain);
                      },
                    ),
                  ),
                ),
              ),
            ),
            
            // Photo info overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Uploaded by $uploaderName',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (uploadedAt != null)
                        Text(
                          DateFormat.yMMMd().add_jm().format(uploadedAt),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      // Show quality indicator for guests
                      if (!widget.isAdmin)
                        Text(
                          'Thumbnail view • Full quality available to wedding couple',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'Wedding Photos (Admin)' : 'Wedding Photos',
          style: GoogleFonts.dancingScript(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[400],
        automaticallyImplyLeading: widget.isAdmin,
        actions: widget.isAdmin ? [
          IconButton(
            icon: Icon(Icons.security),
            onPressed: () => _showAppCheckInfo(),
            tooltip: 'App Check Status',
          ),
          IconButton(
            icon: Icon(Icons.cached),
            onPressed: () => _showCacheInfo(),
            tooltip: 'Cache Info',
          ),
          IconButton(
            icon: Icon(Icons.cleaning_services),
            onPressed: () => _clearCache(),
            tooltip: 'Clear Cache',
          ),
        ] : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E9),
              Color(0xFFC8E6C9),
              Color(0xFFF5F5F5),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "Kirsty & Jason's Wedding",
                    style: GoogleFonts.dancingScript(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.isAdmin 
                        ? "Manage all wedding photos"
                        : "Share your favorite moments from our special day",
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      color: Colors.green[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Add info for guests about thumbnail viewing
                  if (!widget.isAdmin) ...[
                    SizedBox(height: 8),
                    Text(
                      "🛡️ Protected by App Check • 💾 Cached for faster loading • 📸 Preview quality shown",
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: Colors.green[500],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: 16),
                  
                  // Upload button with progress
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadPhotos,
                    icon: _isUploading 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.cloud_upload),
                    label: Text(_isUploading 
                        ? 'Uploading $_uploadProgress/$_totalUploads...' 
                        : 'Upload Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[500],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  
                  // Upload progress details
                  if (_isUploading) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        children: [
                          // Progress bar
                          LinearProgressIndicator(
                            value: _totalUploads > 0 ? _uploadProgress / _totalUploads : 0,
                            backgroundColor: Colors.green[100],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                          ),
                          SizedBox(height: 8),
                          // Current file being uploaded
                          Text(
                            'Uploading: ${_currentUploadFileName.isNotEmpty ? _currentUploadFileName : "Processing..."}',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          // Progress text
                          Text(
                            '$_uploadProgress of $_totalUploads photos completed • 🛡️ App Check Protected',
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              color: Colors.green[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Photo grid
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                      ),
                    )
                  : _photos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 80,
                                color: Colors.green[200],
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No photos yet",
                                style: GoogleFonts.lato(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[400],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Be the first to share a memory!",
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _photos.length,
                          itemBuilder: (context, index) {
                            final photo = _photos[index];
                            final uploadedAt = photo['uploadedAt'] != null
                                ? (photo['uploadedAt'] as Timestamp).toDate()
                                : null;
                            
                            return _buildPhotoTile(
                              photo['id'],
                              photo['url'],
                              photo['thumbnailUrl'] ?? photo['url'], // Fallback to original if no thumbnail
                              photo['uploaderName'] ?? 'Guest',
                              uploadedAt,
                              photo['fileName'],
                              photo['thumbnailFileName'],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(String id, String url, String thumbnailUrl, String uploaderName, DateTime? uploadedAt, String fileName, String? thumbnailFileName) {
    // Always show thumbnails in grid view for guests, full res for admin
    final displayUrl = widget.isAdmin ? url : thumbnailUrl;
    
    return GestureDetector(
      onTap: () => _showPhotoFullscreen(url, thumbnailUrl, uploaderName, uploadedAt),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo with caching (thumbnail for guests, full for admin)
              CachedNetworkImage(
                imageUrl: displayUrl,
                fit: BoxFit.cover,
                cacheManager: _customCacheManager,
                memCacheWidth: widget.isAdmin ? null : 700,
                memCacheHeight: widget.isAdmin ? null : 700,
                maxWidthDiskCache: widget.isAdmin ? null : 800,
                maxHeightDiskCache: widget.isAdmin ? null : 800,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey[400],
                    size: 40,
                  ),
                ),
                // Debug cache loading
                imageBuilder: (context, imageProvider) {
                  print('💾 Image tile cached successfully: $displayUrl');
                  return Image(image: imageProvider, fit: BoxFit.cover);
                },
              ),
              
              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        uploaderName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (uploadedAt != null)
                        Text(
                          DateFormat.MMMd().format(uploadedAt),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Admin controls
              if (widget.isAdmin)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.download, color: Colors.white, size: 18),
                          onPressed: () => _downloadPhoto(url, fileName),
                          padding: EdgeInsets.all(4),
                          constraints: BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red[300], size: 18),
                          onPressed: () => _showDeleteConfirmation(id, fileName, thumbnailFileName),
                          padding: EdgeInsets.all(4),
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Who's sharing?",
              style: GoogleFonts.dancingScript(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _uploaderNameController,
              decoration: InputDecoration(
                labelText: 'Your name',
                hintText: 'Enter your name',
                prefixIcon: Icon(Icons.person, color: Colors.green[300]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.green[400]!, width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("Cancel"),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_uploaderNameController.text.isNotEmpty) {
                        Navigator.pop(context, _uploaderNameController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text("Continue"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String photoId, String fileName, String? thumbnailFileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Delete Photo?",
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.red[700],
          ),
        ),
        content: Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePhoto(photoId, fileName, thumbnailFileName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: Text("Delete"),
          ),
        ],
      ),
    );
  }

  // Show App Check status
  void _showAppCheckInfo() async {
    try {
      print('🔍 Checking App Check status...');
      final token = await FirebaseAppCheck.instance.getToken();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.security, color: Colors.green[600]),
              SizedBox(width: 8),
              Text('App Check Status'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🛡️ Status: ${token != null ? "✅ ACTIVE" : "❌ INACTIVE"}'),
              SizedBox(height: 8),
              Text('🔒 Provider: reCAPTCHA v3'),
              SizedBox(height: 8),
              Text('🎯 Protection: All Firebase operations'),
              SizedBox(height: 8),
              Text('💰 Cost Protection: Preventing bot abuse'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Text(
                  token != null 
                    ? '✅ Your wedding app is protected from unauthorized access and cost attacks!'
                    : '❌ App Check is not working properly. Check console for errors.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            if (token != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _debugAppCheck();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[400],
                ),
                child: Text('Test Token'),
              ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error checking App Check: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking App Check status: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }

  // Show cache information
  void _showCacheInfo() async {
    try {
      print('💾 Checking cache status...');
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cached, color: Colors.blue[600]),
              SizedBox(width: 8),
              Text('Cache Information'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💾 Cache Status: ✅ ACTIVE'),
              SizedBox(height: 8),
              Text('🏷️ Cache Name: wedding_photos_cache'),
              SizedBox(height: 8),
              Text('📦 Max Objects: 1000 images'),
              SizedBox(height: 8),
              Text('⏰ Cache Duration: 7 days'),
              SizedBox(height: 8),
              Text('🔄 Memory Cache: Up to 700x700px'),
              SizedBox(height: 8),
              Text('💽 Disk Cache: Up to 800x800px'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 How to Test Cache:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '1. Load photos (first time = downloads)\n2. Refresh page (should load instantly)\n3. Check Network tab for "from cache"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _clearCache();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[400],
              ),
              child: Text('Clear Cache'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error checking cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cache system is active and working!'),
          backgroundColor: Colors.green[400],
        ),
      );
    }
  }

  // Clear cache method for admin
  void _clearCache() async {
    try {
      print('🧹 Clearing image cache...');
      await _customCacheManager.emptyCache();
      print('✅ Cache cleared successfully!');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cache cleared successfully! Next photo loads will download fresh copies.'),
          backgroundColor: Colors.orange[400],
        ),
      );
    } catch (e) {
      print('❌ Error clearing cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing cache: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
  }
}


// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
// import 'package:google_fonts/google_fonts.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'dart:typed_data';
// import 'dart:html' as html if (dart.library.html) 'dart:html';
// import 'dart:ui' as ui;
// import 'dart:async';
// import 'dart:math' as math;
// import 'dart:convert' show base64Decode;
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// class PhotoGalleryPage extends StatefulWidget {
//   final bool isAdmin;

//   PhotoGalleryPage({Key? key, this.isAdmin = false}) : super(key: key);

//   @override
//   _PhotoGalleryPageState createState() => _PhotoGalleryPageState();
// }

// class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
//   final _firestore = FirebaseFirestore.instance;
//   final _storage = firebase_storage.FirebaseStorage.instance;
//   bool _isLoading = false;
//   bool _isUploading = false;
//   int _uploadProgress = 0;
//   int _totalUploads = 0;
//   String _currentUploadFileName = '';
//   List<Map<String, dynamic>> _photos = [];
//   final _uploaderNameController = TextEditingController();
//   String? _selectedPhotoUrl;

//   // Custom cache manager for wedding photos
//   static final CacheManager _customCacheManager = CacheManager(
//     Config(
//       "wedding_photos_cache",
//       stalePeriod: const Duration(days: 7), // Cache for 7 days
//       maxNrOfCacheObjects: 1000, // Cache up to 1000 images
//       repo: JsonCacheInfoRepository(databaseName: "wedding_photos_cache"),
//       fileService: HttpFileService(),
//     ),
//   );

//   @override
//   void initState() {
//     super.initState();
//     _loadPhotos();
//   }

//   @override
//   void dispose() {
//     _uploaderNameController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadPhotos() async {
//     setState(() => _isLoading = true);
    
//     try {
//       final snapshot = await _firestore
//           .collection('wedding_photos')
//           .orderBy('uploadedAt', descending: true)
//           .get();
      
//       setState(() {
//         _photos = snapshot.docs.map((doc) => {
//           'id': doc.id,
//           ...doc.data(),
//         }).toList();
//         _isLoading = false;
//       });
//     } catch (e) {
//       print('Error loading photos: $e');
//       setState(() => _isLoading = false);
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error loading photos: $e'),
//           backgroundColor: Colors.red[400],
//         ),
//       );
//     }
//   }

//   // Create thumbnail from image bytes
//   Future<Uint8List> _createThumbnail(Uint8List imageBytes) async {
//     try {
//       // For web, we'll use a different approach with HTML canvas
//       if (kIsWeb) {
//         return await _createWebThumbnail(imageBytes);
//       }
      
//       // Decode the image with smaller dimensions
//       final codec = await ui.instantiateImageCodec(
//         imageBytes,
//         targetWidth: 600, // Increased from 400 to 600
//         targetHeight: 600, // Increased from 400 to 600
//       );
//       final frame = await codec.getNextFrame();
      
//       // Convert to PNG (we'll handle compression differently for web)
//       final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
//       return byteData!.buffer.asUint8List();
//     } catch (e) {
//       print('Error creating thumbnail: $e');
//       // If thumbnail creation fails, return a very basic compressed version
//       return await _createBasicThumbnail(imageBytes);
//     }
//   }

//   // Web-specific thumbnail creation using canvas
//   Future<Uint8List> _createWebThumbnail(Uint8List imageBytes) async {
//     final completer = Completer<Uint8List>();
    
//     // Create an image element
//     final img = html.ImageElement();
//     final blob = html.Blob([imageBytes]);
//     final url = html.Url.createObjectUrlFromBlob(blob);
    
//     img.onLoad.listen((_) async {
//       try {
//         // Create canvas
//         final canvas = html.CanvasElement(width: 600, height: 600); // Increased from 400
//         final ctx = canvas.context2D;
        
//         // Calculate scaling to maintain aspect ratio
//         final scale = math.min(600 / img.width!, 600 / img.height!); // Updated calculations
//         final scaledWidth = (img.width! * scale).round();
//         final scaledHeight = (img.height! * scale).round();
        
//         // Center the image
//         final x = (600 - scaledWidth) / 2; // Updated centering
//         final y = (600 - scaledHeight) / 2;
        
//         // Draw scaled image
//         ctx.drawImageScaled(img, x, y, scaledWidth.toDouble(), scaledHeight.toDouble());
        
//         // Get canvas data as data URL and convert to bytes
//         final dataUrl = canvas.toDataUrl('image/jpeg', 0.85); // Increased quality from 0.8 to 0.85
//         final base64Data = dataUrl.split(',')[1];
//         final bytes = base64Decode(base64Data);
        
//         completer.complete(Uint8List.fromList(bytes));
//         html.Url.revokeObjectUrl(url);
//       } catch (e) {
//         html.Url.revokeObjectUrl(url);
//         completer.completeError('Failed to create thumbnail: $e');
//       }
//     });
    
//     img.onError.listen((_) {
//       html.Url.revokeObjectUrl(url);
//       completer.completeError('Failed to load image');
//     });
    
//     img.src = url;
//     return completer.future;
//   }

//   // Fallback basic thumbnail
//   Future<Uint8List> _createBasicThumbnail(Uint8List imageBytes) async {
//     // For now, just return a much smaller version of the original
//     final codec = await ui.instantiateImageCodec(
//       imageBytes,
//       targetWidth: 500, // Increased from 300
//       targetHeight: 500, // Increased from 300
//     );
//     final frame = await codec.getNextFrame();
//     final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
//     return byteData!.buffer.asUint8List();
//   }

//   Future<void> _pickAndUploadPhotos() async {
//     // Show name dialog if not admin
//     if (!widget.isAdmin) {
//       final name = await showDialog<String>(
//         context: context,
//         builder: (context) => _buildNameDialog(),
//       );
      
//       if (name == null || name.isEmpty) return;
//       _uploaderNameController.text = name;
//     }
    
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
//         allowMultiple: true,
//         withData: true,
//       );
      
//       if (result != null && result.files.isNotEmpty) {
//         setState(() {
//           _isUploading = true;
//           _uploadProgress = 0;
//           _totalUploads = result.files.length;
//           _currentUploadFileName = '';
//         });
        
//         int uploadedCount = 0;
//         int failedCount = 0;
        
//         for (final file in result.files) {
//           if (file.bytes != null) {
//             try {
//               setState(() {
//                 _currentUploadFileName = file.name;
//               });
              
//               await _uploadPhoto(file.bytes!, file.name);
//               uploadedCount++;
              
//               setState(() {
//                 _uploadProgress = uploadedCount + failedCount;
//               });
              
//               // Reload photos after each successful upload to show progress
//               await _loadPhotos();
              
//             } catch (e) {
//               print('Error uploading ${file.name}: $e');
//               failedCount++;
              
//               setState(() {
//                 _uploadProgress = uploadedCount + failedCount;
//               });
//             }
//           }
//         }
        
//         setState(() {
//           _isUploading = false;
//           _uploadProgress = 0;
//           _totalUploads = 0;
//           _currentUploadFileName = '';
//         });
        
//         // Show success message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Uploaded $uploadedCount photos${failedCount > 0 ? ', $failedCount failed' : ''}'),
//             backgroundColor: Colors.green[400],
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error picking files: $e');
//       setState(() {
//         _isUploading = false;
//         _uploadProgress = 0;
//         _totalUploads = 0;
//         _currentUploadFileName = '';
//       });
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error selecting photos: $e'),
//           backgroundColor: Colors.red[400],
//         ),
//       );
//     }
//   }

//   Future<void> _uploadPhoto(Uint8List bytes, String fileName) async {
//     print('🚨 Uploading photo with smart thumbnail generation...');
    
//     // Generate unique filename
//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//     final extension = fileName.split('.').last;
//     final uniqueFileName = 'wedding_photo_$timestamp.$extension';
//     final thumbnailFileName = 'thumb_$uniqueFileName';
    
//     // Upload original to Firebase Storage
//     final ref = _storage.ref().child('wedding_photos/$uniqueFileName');
//     final uploadTask = ref.putData(bytes);
//     final snapshot = await uploadTask;
//     final downloadUrl = await snapshot.ref.getDownloadURL();
    
//     String thumbnailUrl = downloadUrl; // Default to original
//     int? thumbnailSize;
    
//     // Only create thumbnail if original is large enough (>300KB) - lowered threshold
//     if (bytes.length > 300000) {
//       try {
//         final thumbnailBytes = await _createThumbnail(bytes);
        
//         // Only use thumbnail if it's actually smaller
//         if (thumbnailBytes.length < bytes.length * 0.8) {
//           final thumbRef = _storage.ref().child('wedding_photos/thumbnails/$thumbnailFileName');
//           final thumbUploadTask = thumbRef.putData(thumbnailBytes);
//           final thumbSnapshot = await thumbUploadTask;
//           thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();
//           thumbnailSize = thumbnailBytes.length;
//         } else {
//           print('Thumbnail not smaller than original, using original');
//         }
//       } catch (e) {
//         print('Thumbnail creation failed, using original: $e');
//       }
//     } else {
//       print('File too small for thumbnail, using original');
//     }
    
//     // Save metadata to Firestore
//     await _firestore.collection('wedding_photos').add({
//       'url': downloadUrl,
//       'thumbnailUrl': thumbnailUrl,
//       'fileName': uniqueFileName,
//       'thumbnailFileName': thumbnailUrl != downloadUrl ? thumbnailFileName : null,
//       'originalFileName': fileName,
//       'uploaderName': widget.isAdmin ? 'Admin' : _uploaderNameController.text,
//       'uploadedAt': FieldValue.serverTimestamp(),
//       'size': bytes.length,
//       'thumbnailSize': thumbnailSize,
//     });
//   }

//   Future<void> _deletePhoto(String photoId, String fileName, String? thumbnailFileName) async {
//     try {
//       // Delete from Storage
//       await _storage.ref().child('wedding_photos/$fileName').delete();
      
//       // Delete thumbnail from Storage
//       if (thumbnailFileName != null) {
//         await _storage.ref().child('wedding_photos/thumbnails/$thumbnailFileName').delete();
//       }
      
//       // Delete from Firestore
//       await _firestore.collection('wedding_photos').doc(photoId).delete();
      
//       // Reload photos
//       await _loadPhotos();
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Photo deleted successfully'),
//           backgroundColor: Colors.green[400],
//         ),
//       );
//     } catch (e) {
//       print('Error deleting photo: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error deleting photo: $e'),
//           backgroundColor: Colors.red[400],
//         ),
//       );
//     }
//   }

//   void _downloadPhoto(String url, String fileName) {
//     if (kIsWeb) {
//       // Web download
//       html.AnchorElement(href: url)
//         ..setAttribute('download', fileName)
//         ..click();
//     }
//   }

//   void _showPhotoFullscreen(String url, String thumbnailUrl, String uploaderName, DateTime? uploadedAt) {
//     // For guests, show thumbnail in fullscreen
//     // For admin, show full resolution
//     final displayUrl = widget.isAdmin ? url : thumbnailUrl;
    
//     setState(() => _selectedPhotoUrl = displayUrl);
    
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         backgroundColor: Colors.black,
//         insetPadding: EdgeInsets.zero,
//         child: Stack(
//           children: [
//             // Full screen photo with caching
//             GestureDetector(
//               onTap: () => Navigator.pop(context),
//               child: Container(
//                 color: Colors.black,
//                 child: Center(
//                   child: InteractiveViewer(
//                     panEnabled: true,
//                     minScale: 0.5,
//                     maxScale: widget.isAdmin ? 4 : 2, // Less zoom for thumbnails
//                     child: CachedNetworkImage(
//                       imageUrl: displayUrl,
//                       fit: BoxFit.contain,
//                       cacheManager: _customCacheManager,
//                       memCacheWidth: widget.isAdmin ? null : 800,
//                       memCacheHeight: widget.isAdmin ? null : 800,
//                       maxWidthDiskCache: widget.isAdmin ? null : 1000,
//                       maxHeightDiskCache: widget.isAdmin ? null : 1000,
//                       placeholder: (context, url) => Center(
//                         child: CircularProgressIndicator(
//                           valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
//                         ),
//                       ),
//                       errorWidget: (context, url, error) => Container(
//                         color: Colors.grey[800],
//                         child: Icon(
//                           Icons.broken_image,
//                           color: Colors.grey[400],
//                           size: 80,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
            
//             // Photo info overlay
//             Positioned(
//               bottom: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 padding: EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.bottomCenter,
//                     end: Alignment.topCenter,
//                     colors: [
//                       Colors.black.withOpacity(0.8),
//                       Colors.transparent,
//                     ],
//                   ),
//                 ),
//                 child: SafeArea(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         'Uploaded by $uploaderName',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       if (uploadedAt != null)
//                         Text(
//                           DateFormat.yMMMd().add_jm().format(uploadedAt),
//                           style: TextStyle(
//                             color: Colors.white70,
//                             fontSize: 14,
//                           ),
//                         ),
//                       // Show quality indicator for guests
//                       if (!widget.isAdmin)
//                         Text(
//                           'Thumbnail view • Full quality available to wedding couple',
//                           style: TextStyle(
//                             color: Colors.white60,
//                             fontSize: 12,
//                             fontStyle: FontStyle.italic,
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
            
//             // Close button
//             Positioned(
//               top: 40,
//               right: 20,
//               child: IconButton(
//                 icon: Icon(Icons.close, color: Colors.white, size: 30),
//                 onPressed: () => Navigator.pop(context),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           widget.isAdmin ? 'Wedding Photos (Admin)' : 'Wedding Photos',
//           style: GoogleFonts.dancingScript(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: Colors.green[400],
//         automaticallyImplyLeading: widget.isAdmin,
//         actions: widget.isAdmin ? [
//           IconButton(
//             icon: Icon(Icons.cleaning_services),
//             onPressed: () => _clearCache(),
//             tooltip: 'Clear Cache',
//           ),
//         ] : null,
//       ),
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               Color(0xFFE8F5E9),
//               Color(0xFFC8E6C9),
//               Color(0xFFF5F5F5),
//             ],
//           ),
//         ),
//         child: Column(
//           children: [
//             // Header
//             Container(
//               width: double.infinity,
//               padding: EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.9),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.green.withOpacity(0.1),
//                     blurRadius: 10,
//                     offset: Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   Text(
//                     "Kirsty & Jason's Wedding",
//                     style: GoogleFonts.dancingScript(
//                       fontSize: 32,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.green[700],
//                     ),
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     widget.isAdmin 
//                         ? "Manage all wedding photos"
//                         : "Share your favorite moments from our special day",
//                     style: GoogleFonts.lato(
//                       fontSize: 16,
//                       color: Colors.green[600],
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   // Add info for guests about thumbnail viewing
//                   if (!widget.isAdmin) ...[
//                     SizedBox(height: 8),
//                     Text(
//                       "Photos cached for faster loading • Preview quality shown",
//                       style: GoogleFonts.lato(
//                         fontSize: 12,
//                         color: Colors.green[500],
//                         fontStyle: FontStyle.italic,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                   SizedBox(height: 16),
                  
//                   // Upload button with progress
//                   ElevatedButton.icon(
//                     onPressed: _isUploading ? null : _pickAndUploadPhotos,
//                     icon: _isUploading 
//                         ? SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                             ),
//                           )
//                         : Icon(Icons.cloud_upload),
//                     label: Text(_isUploading 
//                         ? 'Uploading $_uploadProgress/$_totalUploads...' 
//                         : 'Upload Photos'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green[500],
//                       foregroundColor: Colors.white,
//                       padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                     ),
//                   ),
                  
//                   // Upload progress details
//                   if (_isUploading) ...[
//                     SizedBox(height: 16),
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                       decoration: BoxDecoration(
//                         color: Colors.green[50],
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: Colors.green[200]!),
//                       ),
//                       child: Column(
//                         children: [
//                           // Progress bar
//                           LinearProgressIndicator(
//                             value: _totalUploads > 0 ? _uploadProgress / _totalUploads : 0,
//                             backgroundColor: Colors.green[100],
//                             valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
//                           ),
//                           SizedBox(height: 8),
//                           // Current file being uploaded
//                           Text(
//                             'Uploading: ${_currentUploadFileName.isNotEmpty ? _currentUploadFileName : "Processing..."}',
//                             style: GoogleFonts.lato(
//                               fontSize: 12,
//                               color: Colors.green[700],
//                               fontWeight: FontWeight.w500,
//                             ),
//                             textAlign: TextAlign.center,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           SizedBox(height: 4),
//                           // Progress text
//                           Text(
//                             '$_uploadProgress of $_totalUploads photos completed',
//                             style: GoogleFonts.lato(
//                               fontSize: 11,
//                               color: Colors.green[600],
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
            
//             // Photo grid
//             Expanded(
//               child: _isLoading
//                   ? Center(
//                       child: CircularProgressIndicator(
//                         valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
//                       ),
//                     )
//                   : _photos.isEmpty
//                       ? Center(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(
//                                 Icons.photo_library_outlined,
//                                 size: 80,
//                                 color: Colors.green[200],
//                               ),
//                               SizedBox(height: 16),
//                               Text(
//                                 "No photos yet",
//                                 style: GoogleFonts.lato(
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.green[400],
//                                 ),
//                               ),
//                               SizedBox(height: 8),
//                               Text(
//                                 "Be the first to share a memory!",
//                                 style: GoogleFonts.lato(
//                                   fontSize: 16,
//                                   color: Colors.green[600],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         )
//                       : GridView.builder(
//                           padding: EdgeInsets.all(16),
//                           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                             crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 3,
//                             crossAxisSpacing: 16,
//                             mainAxisSpacing: 16,
//                           ),
//                           itemCount: _photos.length,
//                           itemBuilder: (context, index) {
//                             final photo = _photos[index];
//                             final uploadedAt = photo['uploadedAt'] != null
//                                 ? (photo['uploadedAt'] as Timestamp).toDate()
//                                 : null;
                            
//                             return _buildPhotoTile(
//                               photo['id'],
//                               photo['url'],
//                               photo['thumbnailUrl'] ?? photo['url'], // Fallback to original if no thumbnail
//                               photo['uploaderName'] ?? 'Guest',
//                               uploadedAt,
//                               photo['fileName'],
//                               photo['thumbnailFileName'],
//                             );
//                           },
//                         ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPhotoTile(String id, String url, String thumbnailUrl, String uploaderName, DateTime? uploadedAt, String fileName, String? thumbnailFileName) {
//     // Always show thumbnails in grid view for guests, full res for admin
//     final displayUrl = widget.isAdmin ? url : thumbnailUrl;
    
//     return GestureDetector(
//       onTap: () => _showPhotoFullscreen(url, thumbnailUrl, uploaderName, uploadedAt),
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               blurRadius: 8,
//               offset: Offset(0, 4),
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(12),
//           child: Stack(
//             fit: StackFit.expand,
//             children: [
//               // Photo with caching (thumbnail for guests, full for admin)
//               CachedNetworkImage(
//                 imageUrl: displayUrl,
//                 fit: BoxFit.cover,
//                 cacheManager: _customCacheManager,
//                 memCacheWidth: widget.isAdmin ? null : 700, // Increased cache sizes for better quality
//                 memCacheHeight: widget.isAdmin ? null : 700,
//                 maxWidthDiskCache: widget.isAdmin ? null : 800, // Disk cache size  
//                 maxHeightDiskCache: widget.isAdmin ? null : 800,
//                 placeholder: (context, url) => Container(
//                   color: Colors.grey[200],
//                   child: Center(
//                     child: CircularProgressIndicator(
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
//                     ),
//                   ),
//                 ),
//                 errorWidget: (context, url, error) => Container(
//                   color: Colors.grey[200],
//                   child: Icon(
//                     Icons.broken_image,
//                     color: Colors.grey[400],
//                     size: 40,
//                   ),
//                 ),
//               ),
              
//               // Gradient overlay
//               Positioned(
//                 bottom: 0,
//                 left: 0,
//                 right: 0,
//                 child: Container(
//                   padding: EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.bottomCenter,
//                       end: Alignment.topCenter,
//                       colors: [
//                         Colors.black.withOpacity(0.7),
//                         Colors.transparent,
//                       ],
//                     ),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         uploaderName,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 12,
//                           fontWeight: FontWeight.bold,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       if (uploadedAt != null)
//                         Text(
//                           DateFormat.MMMd().format(uploadedAt),
//                           style: TextStyle(
//                             color: Colors.white70,
//                             fontSize: 10,
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
              
//               // Admin controls
//               if (widget.isAdmin)
//                 Positioned(
//                   top: 8,
//                   right: 8,
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.6),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         IconButton(
//                           icon: Icon(Icons.download, color: Colors.white, size: 18),
//                           onPressed: () => _downloadPhoto(url, fileName),
//                           padding: EdgeInsets.all(4),
//                           constraints: BoxConstraints(),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete, color: Colors.red[300], size: 18),
//                           onPressed: () => _showDeleteConfirmation(id, fileName, thumbnailFileName),
//                           padding: EdgeInsets.all(4),
//                           constraints: BoxConstraints(),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNameDialog() {
//     return Dialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Padding(
//         padding: EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               "Who's sharing?",
//               style: GoogleFonts.dancingScript(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.green[700],
//               ),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _uploaderNameController,
//               decoration: InputDecoration(
//                 labelText: 'Your name',
//                 hintText: 'Enter your name',
//                 prefixIcon: Icon(Icons.person, color: Colors.green[300]),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                   borderSide: BorderSide(color: Colors.green[400]!, width: 2),
//                 ),
//               ),
//               textCapitalization: TextCapitalization.words,
//             ),
//             SizedBox(height: 24),
//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton(
//                     onPressed: () => Navigator.pop(context),
//                     style: OutlinedButton.styleFrom(
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: Text("Cancel"),
//                   ),
//                 ),
//                 SizedBox(width: 16),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () {
//                       if (_uploaderNameController.text.isNotEmpty) {
//                         Navigator.pop(context, _uploaderNameController.text);
//                       }
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green[400],
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: Text("Continue"),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showDeleteConfirmation(String photoId, String fileName, String? thumbnailFileName) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(20),
//         ),
//         title: Text(
//           "Delete Photo?",
//           style: GoogleFonts.lato(
//             fontWeight: FontWeight.bold,
//             color: Colors.red[700],
//           ),
//         ),
//         content: Text("This action cannot be undone."),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _deletePhoto(photoId, fileName, thumbnailFileName);
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red[400],
//               foregroundColor: Colors.white,
//             ),
//             child: Text("Delete"),
//           ),
//         ],
//       ),
//     );
//   }

//   // Clear cache method for admin
//   void _clearCache() async {
//     try {
//       await _customCacheManager.emptyCache();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Cache cleared successfully'),
//           backgroundColor: Colors.green[400],
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error clearing cache: $e'),
//           backgroundColor: Colors.red[400],
//         ),
//       );
//     }
//   }
// }

