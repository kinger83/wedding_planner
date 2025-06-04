import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:html' as html if (dart.library.html) 'dart:html';

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
  List<Map<String, dynamic>> _photos = [];
  final _uploaderNameController = TextEditingController();
  String? _selectedPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void dispose() {
    _uploaderNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await _firestore
          .collection('wedding_photos')
          .orderBy('uploadedAt', descending: true)
          .get();
      
      setState(() {
        _photos = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading photos: $e');
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading photos: $e'),
          backgroundColor: Colors.red[400],
        ),
      );
    }
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
      setState(() => _isUploading = true);
      
      int uploadedCount = 0;
      int failedCount = 0;
      
      for (final file in result.files) {
        if (file.bytes != null) {
          try {
            await _uploadPhoto(file.bytes!, file.name);
            uploadedCount++;
          } catch (e) {
            print('Error uploading ${file.name}: $e');
            failedCount++;
          }
        }
      }
      
      setState(() => _isUploading = false);
      
      // Reload photos
      await _loadPhotos();
      
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
    setState(() => _isUploading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error selecting photos: $e'),
        backgroundColor: Colors.red[400],
      ),
    );
  }
}

Future<void> _uploadPhoto(Uint8List bytes, String fileName) async {
  print('🚨 Using original working method...');
  
  // Generate unique filename
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final extension = fileName.split('.').last;
  final uniqueFileName = 'wedding_photo_$timestamp.$extension';
  
  // Upload to Firebase Storage
  final ref = _storage.ref().child('wedding_photos/$uniqueFileName');
  final uploadTask = ref.putData(bytes);
  final snapshot = await uploadTask;
  final downloadUrl = await snapshot.ref.getDownloadURL();
  
  // Save metadata to Firestore
  await _firestore.collection('wedding_photos').add({
    'url': downloadUrl,
    'fileName': uniqueFileName,
    'originalFileName': fileName,
    'uploaderName': widget.isAdmin ? 'Admin' : _uploaderNameController.text,
    'uploadedAt': FieldValue.serverTimestamp(),
    'size': bytes.length,
  });
}
// Future<void> _pickAndUploadPhotos() async {
//   if (!kIsWeb) return;
  
//   // Show name dialog if not admin
//   if (!widget.isAdmin) {
//     final name = await showDialog<String>(
//       context: context,
//       builder: (context) => _buildNameDialog(),
//     );
    
//     if (name == null || name.isEmpty) return;
//     _uploaderNameController.text = name;
//   }
  
//   final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
//   uploadInput.accept = 'image/*';
//   uploadInput.multiple = true;
  
//   uploadInput.onChange.listen((e) {
//     final files = uploadInput.files;
//     if (files == null || files.isEmpty) return;
    
//     setState(() => _isUploading = true);
    
//     int totalFiles = files.length;
//     int uploadedCount = 0;
//     int failedCount = 0;
    
//     for (final file in files) {
//       final reader = html.FileReader();
//       reader.readAsArrayBuffer(file);
//       reader.onLoadEnd.listen((e) async {
//         try {
//           final bytes = reader.result as List<int>;
//           await _uploadPhoto(Uint8List.fromList(bytes), file.name);
//           uploadedCount++;
//         } catch (error) {
//           print('Error uploading ${file.name}: $error');
//           failedCount++;
//         }
        
//         // Check if all files are processed
//         if (uploadedCount + failedCount == totalFiles) {
//           setState(() => _isUploading = false);
          
//           // Reload photos
//           await _loadPhotos();
          
//           // Show success message
//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('Uploaded $uploadedCount photos${failedCount > 0 ? ', $failedCount failed' : ''}'),
//                 backgroundColor: Colors.green[400],
//               ),
//             );
//           }
//         }
//       });
//     }
//   });
  
//   uploadInput.click();
// }

// Future<void> _uploadPhoto(Uint8List bytes, String fileName) async {
//   print('🚨 Testing Firestore connection first...');
  
//   try {
//     // Test Firestore first (simpler)
//     await _firestore.collection('test').add({
//       'message': 'test connection',
//       'timestamp': FieldValue.serverTimestamp(),
//     });
    
//     print('✅ Firestore connection successful!');
    
//     // If Firestore works, now try Storage
//     print('🚨 Now testing Firebase Storage...');
//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//     final storageRef = _storage.ref().child('test_$timestamp.txt');
    
//     final testBytes = Uint8List.fromList('hello world'.codeUnits);
//     await storageRef.putData(testBytes);
    
//     print('✅ Firebase Storage test successful!');
//   } catch (e) {
//     print('❌ Error: $e');
//     throw e;
//   }
// }


  // Future<void> _pickAndUploadPhotos() async {
  //   // Show name dialog if not admin
  //   if (!widget.isAdmin) {
  //     final name = await showDialog<String>(
  //       context: context,
  //       builder: (context) => _buildNameDialog(),
  //     );
      
  //     if (name == null || name.isEmpty) return;
  //     _uploaderNameController.text = name;
  //   }
    
  //   try {
  //     final result = await FilePicker.platform.pickFiles(
  //       type: FileType.custom,
  //       allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
  //       allowMultiple: true,
  //       withData: true,
  //     );
      
  //     if (result != null && result.files.isNotEmpty) {
  //       setState(() => _isUploading = true);
        
  //       int uploadedCount = 0;
  //       int failedCount = 0;
        
  //       for (final file in result.files) {
  //         if (file.bytes != null) {
  //           try {
  //             await _uploadPhoto(file.bytes!, file.name);
  //             uploadedCount++;
  //           } catch (e) {
  //             print('Error uploading ${file.name}: $e');
  //             failedCount++;
  //           }
  //         }
  //       }
        
  //       setState(() => _isUploading = false);
        
  //       // Reload photos
  //       await _loadPhotos();
        
  //       // Show success message
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Uploaded $uploadedCount photos${failedCount > 0 ? ', $failedCount failed' : ''}'),
  //           backgroundColor: Colors.green[400],
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     print('Error picking files: $e');
  //     setState(() => _isUploading = false);
      
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error selecting photos: $e'),
  //         backgroundColor: Colors.red[400],
  //       ),
  //     );
  //   }
  // }





  // Future<void> _uploadPhoto(Uint8List bytes, String fileName) async {
  //   // Generate unique filename
  //   final timestamp = DateTime.now().millisecondsSinceEpoch;
  //   final extension = fileName.split('.').last;
  //   final uniqueFileName = 'wedding_photo_$timestamp.$extension';
    
  //   // Upload to Firebase Storage
  //   final ref = _storage.ref().child('wedding_photos/$uniqueFileName');
  //   final uploadTask = ref.putData(bytes);
  //   final snapshot = await uploadTask;
  //   final downloadUrl = await snapshot.ref.getDownloadURL();
    
  //   // Save metadata to Firestore
  //   await _firestore.collection('wedding_photos').add({
  //     'url': downloadUrl,
  //     'fileName': uniqueFileName,
  //     'originalFileName': fileName,
  //     'uploaderName': widget.isAdmin ? 'Admin' : _uploaderNameController.text,
  //     'uploadedAt': FieldValue.serverTimestamp(),
  //     'size': bytes.length,
  //   });
  // }

  Future<void> _deletePhoto(String photoId, String fileName) async {
    try {
      // Delete from Storage
      await _storage.ref().child('wedding_photos/$fileName').delete();
      
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
      // Web download
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
    }
  }

  String _getContentType(String extension) {
  switch (extension.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}

  void _showPhotoFullscreen(String url, String uploaderName, DateTime? uploadedAt) {
    setState(() => _selectedPhotoUrl = url);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Full screen photo
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black,
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                          ),
                        );
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
                  SizedBox(height: 16),
                  
                  // Upload button
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
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[500],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
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
                              photo['uploaderName'] ?? 'Guest',
                              uploadedAt,
                              photo['fileName'],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(String id, String url, String uploaderName, DateTime? uploadedAt, String fileName) {
    return GestureDetector(
      onTap: () => _showPhotoFullscreen(url, uploaderName, uploadedAt),
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
              // Photo
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  );
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
                          onPressed: () => _showDeleteConfirmation(id, fileName),
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

  void _showDeleteConfirmation(String photoId, String fileName) {
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
              _deletePhoto(photoId, fileName);
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
}