import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wedding_app/utils/qr_code_generator.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'package:http/http.dart' as http;

// Guest model for dashboard use
class DashboardGuest {
  String name;
  String? response;
  bool isGlutenIntolerant;
  String groupName;
  String groupId;
  
  DashboardGuest({
    required this.name,
    this.response,
    this.isGlutenIntolerant = false,
    required this.groupName,
    required this.groupId,
  });
}

// Add Guest Dialog with Group Support
class AddGuestDialog extends StatefulWidget {
  final Function? onGuestAdded;

  AddGuestDialog({this.onGuestAdded});

  @override
  _AddGuestDialogState createState() => _AddGuestDialogState();
}

class _AddGuestDialogState extends State<AddGuestDialog> {
  final _groupNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isAdding = false;
  bool _isMounted = false;
  
  // List to store guest name controllers
  List<TextEditingController> _guestControllers = [];

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    
    // Add first guest field by default
    _addGuestField();
  }

  @override
  void dispose() {
    _isMounted = false;
    _groupNameController.dispose();
    _emailController.dispose();
    
    // Dispose all guest controllers
    for (var controller in _guestControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }

  // Safe setState alternative
  void setStateIfMounted(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }
  
  // Add a new guest field
  void _addGuestField() {
    setStateIfMounted(() {
      _guestControllers.add(TextEditingController());
    });
  }
  
  // Remove a guest field
  void _removeGuestField(int index) {
    if (_guestControllers.length > 1) {
      final controller = _guestControllers[index];
      setStateIfMounted(() {
        _guestControllers.removeAt(index);
      });
      controller.dispose();
    }
  }

  Future<void> _addGuests() async {
    print('------------ ADD GUESTS START ------------');
    if (_groupNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a group or family name')),
      );
      return;
    }
    
    // Check if at least one guest name is filled
    bool hasGuest = false;
    for (var controller in _guestControllers) {
      if (controller.text.isNotEmpty) {
        hasGuest = true;
        break;
      }
    }
    
    if (!hasGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one guest name')),
      );
      return;
    }
    
    setStateIfMounted(() {
      _isAdding = true;
    });
    
    try {
      // Create guests list
      List<Map<String, dynamic>> guests = [];
      
      for (var controller in _guestControllers) {
        if (controller.text.isNotEmpty) {
          guests.add({
            'name': controller.text.trim(),
            'response': 'Pending',
            'isGlutenIntolerant': false,
          });
        }
      }
      
      // Create the group document
      final groupData = {
        'groupName': _groupNameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'notes': '',
        'songRequest': '',
        'guests': guests,
      };
      
      print('Adding group with data:');
      print('Group name: ${groupData['groupName']}');
      print('Email: ${groupData['email']}');
      print('Number of guests: ${guests.length}');
      
      final docRef = await FirebaseFirestore.instance.collection('rsvps').add(groupData);
      print('Group added successfully with ID: ${docRef.id}');
      
      if (!_isMounted || !mounted) {
        print('Widget unmounted during group add operation');
        return;
      }
      
      Navigator.pop(context);
      
      if (widget.onGuestAdded != null) {
        widget.onGuestAdded!();
      }
      
      print('------------ ADD GUESTS END ------------');
    } catch (e) {
      print('Error adding guests: $e');
      if (e is Error && e.stackTrace != null) {
        print('Stack trace: ${e.stackTrace}');
      }
      
      if (_isMounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding guests: $e')),
        );
      }
    } finally {
      if (_isMounted && mounted) {
        setStateIfMounted(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFE8F5E9), // Very light green
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add Group/Family",
                style: GoogleFonts.dancingScript(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Create a group invitation for a family or group of guests",
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              
              // Group Name
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'Group/Family Name',
                  labelStyle: TextStyle(color: Colors.green[300]),
                  hintText: 'e.g. The Smith Family',
                  prefixIcon: Icon(Icons.people, color: Colors.green[300]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.green[100]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.green[400]!, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.green[200]!),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.lato(),
              ),
              SizedBox(height: 16),
              
              // Email (optional)
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Contact Email (optional)',
                  labelStyle: TextStyle(color: Colors.green[300]),
                  prefixIcon: Icon(Icons.email, color: Colors.green[300]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.green[100]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.green[400]!, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.green[200]!),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.lato(),
              ),
              SizedBox(height: 24),
              
              // Guest list section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Guest Names",
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Add the names of each individual guest in this group",
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Guest input fields
                    ..._buildGuestFields(),
                    
                    // Add more guests button
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.add, size: 16),
                        label: Text("Add Another Guest"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _addGuestField,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text("Cancel", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAdding ? null : _addGuests,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        elevation: 5,
                        shadowColor: Colors.green.withOpacity(0.5),
                      ),
                      child: _isAdding
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text("Add Group", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build guest input fields
  List<Widget> _buildGuestFields() {
    List<Widget> fields = [];
    
    for (int i = 0; i < _guestControllers.length; i++) {
      fields.add(
        Container(
          margin: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _guestControllers[i],
                  decoration: InputDecoration(
                    labelText: 'Guest ${i + 1}',
                    labelStyle: TextStyle(color: Colors.green[600]),
                    prefixIcon: Icon(Icons.person, color: Colors.green[300], size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              if (_guestControllers.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle, color: Colors.red[300]),
                  onPressed: () => _removeGuestField(i),
                ),
            ],
          ),
        ),
      );
    }
    
    return fields;
  }
}

class RSVPDashboard extends StatefulWidget {
  RSVPDashboard({Key? key}) : super(key: key);

  @override
  _RSVPDashboardState createState() => _RSVPDashboardState();
}

class _RSVPDashboardState extends State<RSVPDashboard> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isMounted = false;
  
  // Stats counters
  int _totalGroups = 0;
  int _totalGuests = 0;
  int _attending = 0;
  int _notAttending = 0;
  int _pending = 0;
  int _glutenFree = 0;
  
  // Lists for organizing data
  List<Map<String, dynamic>> _groups = [];
  List<DashboardGuest> _attendingGuests = [];
  List<DashboardGuest> _pendingGuests = [];
  List<DashboardGuest> _notAttendingGuests = [];
  List<DashboardGuest> _glutenFreeGuests = [];
  List<Map<String, dynamic>> _songRequests = [];
  List<Map<String, dynamic>> _groupNotes = [];
  
  // For the tab controller
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _tabController = TabController(length: 6, vsync: this);
    _loadRSVPData();
  }

  @override
  void dispose() {
    _isMounted = false;
    _tabController.dispose();
    super.dispose();
  }
  
  // Safe setState alternative
  void setStateIfMounted(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadRSVPData() async {
    print('------------ LOAD RSVP DATA START ------------');
    
    try {
      final snapshot = await _firestore.collection('rsvps').get();
      
      if (!_isMounted || !mounted) {
        print('Widget unmounted during data load');
        return;
      }
      
      // Reset all counters and lists
      int totalGroups = 0;
      int totalGuests = 0;
      int attending = 0;
      int notAttending = 0;
      int pending = 0;
      int glutenFree = 0;
      
      List<Map<String, dynamic>> groups = [];
      List<DashboardGuest> attendingGuests = [];
      List<DashboardGuest> pendingGuests = [];
      List<DashboardGuest> notAttendingGuests = [];
      List<DashboardGuest> glutenFreeGuests = [];
      List<Map<String, dynamic>> songRequests = [];
      List<Map<String, dynamic>> groupNotes = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalGroups++;
        
        // Create group data object
        final groupData = {
          'id': doc.id,
          'groupName': data['groupName'] ?? 'Group',
          'email': data['email'] ?? '',
          'respondedAt': data['respondedAt'],
          'notes': data['notes'] ?? '',
          'songRequest': data['songRequest'] ?? '',
          'guests': [],
        };
        
        // Check for song request and notes
        if (groupData['songRequest'].toString().isNotEmpty) {
          songRequests.add({...groupData});
        }
        
        if (groupData['notes'].toString().isNotEmpty) {
          groupNotes.add({...groupData});
        }
        
        // Process guests
        List<dynamic> guestsList = [];
        
        // Handle both formats: new format with 'guests' array and old format with single guest
        if (data.containsKey('guests') && data['guests'] is List) {
          // New format with multiple guests
          guestsList = data['guests'] as List;
        } else {
          // Legacy format - single guest
          guestsList = [{
            'name': data['guestName'] ?? 'Guest',
            'response': data['response'],
            'isGlutenIntolerant': data['isGlutenIntolerant'] ?? false,
          }];
        }
        
        // Process each guest in the group
        List<Map<String, dynamic>> processedGuests = [];
        
        for (var guestData in guestsList) {
          if (guestData is Map<String, dynamic>) {
            totalGuests++;
            
            final name = guestData['name'] ?? 'Guest';
            final response = guestData['response'];
            final isGlutenIntolerant = guestData['isGlutenIntolerant'] == true;
            
            // Add to processed guests list for the group
            processedGuests.add({
              'name': name,
              'response': response,
              'isGlutenIntolerant': isGlutenIntolerant,
            });
            
            // Create dashboard guest object
            final dashboardGuest = DashboardGuest(
              name: name,
              response: response,
              isGlutenIntolerant: isGlutenIntolerant,
              groupName: groupData['groupName'],
              groupId: doc.id,
            );
            
            // Categorize by response
            if (response == 'Yes') {
              attending++;
              attendingGuests.add(dashboardGuest);
              
              if (isGlutenIntolerant) {
                glutenFree++;
                glutenFreeGuests.add(dashboardGuest);
              }
            } else if (response == 'No') {
              notAttending++;
              notAttendingGuests.add(dashboardGuest);
            } else {
              // Handle both 'Pending' and null
              pending++;
              pendingGuests.add(dashboardGuest);
            }
          }
        }
        
        // Add processed guests to group data
        groupData['guests'] = processedGuests;
        groups.add(groupData);
      }

      if (!_isMounted || !mounted) {
        print('Widget unmounted after processing RSVP data');
        return;
      }
      
      setStateIfMounted(() {
        _totalGroups = totalGroups;
        _totalGuests = totalGuests;
        _attending = attending;
        _notAttending = notAttending;
        _pending = pending;
        _glutenFree = glutenFree;
        
        _groups = groups;
        _attendingGuests = attendingGuests;
        _pendingGuests = pendingGuests;
        _notAttendingGuests = notAttendingGuests;
        _glutenFreeGuests = glutenFreeGuests;
        _songRequests = songRequests;
        _groupNotes = groupNotes;
        
        _isLoading = false;
      });
      
      print('RSVP data loaded:');
      print('Total groups: $totalGroups');
      print('Total guests: $totalGuests');
      print('Attending: $attending, Not Attending: $notAttending, Pending: $pending');
      print('Gluten-free: $glutenFree');
      print('------------ LOAD RSVP DATA END ------------');
    } catch (e) {
      print('Error loading RSVP data: $e');
      if (_isMounted && mounted) {
        setStateIfMounted(() {
          _isLoading = false;
        });
      }
    }
  }




Future<void> _generatePdf(String groupName, String rsvpUrl) async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
              ),
              SizedBox(height: 16),
              Text(
                "Creating your RSVP card...",
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  
  try {
    // Get document data to extract guests
    List<String> guests = [];
    Map<String, dynamic>? groupData;
    String groupDesc = groupName;
    
    try {
      final doc = await _firestore.collection('rsvps').doc(rsvpUrl.split('/').last).get();
      if (doc.exists) {
        groupData = doc.data() as Map<String, dynamic>;
        
        // Extract guests and group name
        if (groupData!.containsKey('guests') && groupData['guests'] is List) {
          final guestsList = groupData['guests'] as List;
          for (var guestData in guestsList) {
            if (guestData is Map<String, dynamic>) {
              final name = guestData['name'] ?? 'Guest';
              guests.add(name);
            }
          }
        } else {
          final guestName = groupData['guestName'] ?? 'Guest';
          guests.add(guestName);
        }
        
        if (groupData.containsKey('groupName')) {
          groupDesc = groupData['groupName'];
        }
      }
    } catch (e) {
      print('Error fetching guest data: $e');
    }
    
    // Fetch QR code from external API
    Uint8List? qrImageData;
    try {
      final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(rsvpUrl)}';
      final response = await http.get(Uri.parse(qrUrl));
      
      if (response.statusCode == 200) {
        qrImageData = response.bodyBytes;
      } else {
        print('Failed to load QR code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching QR code: $e');
    }
    
    // Create a PDF document with minimal styling
    final pdf = pw.Document();
    
    // Add page to PDF with very basic styling
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Padding(
            padding: pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header
                pw.Text(
                  'Wedding RSVP',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'KIRSTY & JASON',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 20),
                
                // Main content
                pw.Text(
                  'Dear $groupDesc,',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'We request the pleasure of your company at our wedding celebration.',
                ),
                pw.SizedBox(height: 20),
                
                // Guest list
                if (guests.isNotEmpty) ...[
                  pw.Text(
                    'Guest Names:',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  ...guests.map((guest) => 
                    pw.Text(
                      '- $guest',
                    ),
                  ).toList(),
                  pw.SizedBox(height: 20),
                ],
                
                // QR Code section
                if (qrImageData != null) 
                  pw.Image(pw.MemoryImage(qrImageData), width: 150, height: 150),
                pw.SizedBox(height: 10),
                
                pw.Text(
                  'Please scan to RSVP online',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(rsvpUrl, style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 20),
                
                // Disclaimer
                pw.Text(
                  'This RSVP link is unique to your invitation and should not be shared with others.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                
                // Footer
                pw.SizedBox(height: 20),
                pw.Text(
                  'Forever & Always',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    // First, close loading dialog to prevent UI freezes
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // Now download the files
    try {
      // Web-specific approach: download PDF directly
      final bytes = await pdf.save();
      
      // Create a blob for the PDF and download it
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '${groupDesc.replaceAll(' ', '_')}_RSVP.pdf')
        ..click();
      
      // Add a slight delay before revoking the URL to ensure download starts
      Future.delayed(Duration(seconds: 1), () {
        html.Url.revokeObjectUrl(url);
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('RSVP card created successfully'),
          backgroundColor: Colors.green[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: qrImageData != null ? SnackBarAction(
            label: 'Get QR Code',
            textColor: Colors.white,
            onPressed: () {
              _downloadQrCode(qrImageData!, groupDesc);
            },
          ) : null,
        ),
      );
    } catch (e) {
      print('Error during download: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading files: $e')),
      );
    }
  } catch (e) {
    // Close loading dialog
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('Error generating PDF: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error generating PDF: $e')),
    );
  }
}


Future<void> _generateQrCodeOnly(String groupName, String rsvpUrl) async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
              ),
              SizedBox(height: 16),
              Text(
                "Creating your QR code...",
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  
  try {
    // Get document data to extract guests
    String groupDesc = groupName;
    
    try {
      final doc = await _firestore.collection('rsvps').doc(rsvpUrl.split('/').last).get();
      if (doc.exists) {
        final groupData = doc.data() as Map<String, dynamic>;
        
        if (groupData.containsKey('groupName')) {
          groupDesc = groupData['groupName'];
        }
      }
    } catch (e) {
      print('Error fetching guest data: $e');
    }
    
    // Generate the filename using group name
    String fileName = groupDesc.replaceAll(' ', '_');
    fileName += '_QR.png';
    
    // Remove any special characters that might cause filename issues
    fileName = fileName.replaceAll(RegExp(r'[^\w\-]'), '_');
    
    // Fetch QR code from external API with higher quality
    try {
      // Create a QR code with green color to match website theme
      final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=400x400&margin=10&color=2E7D32&data=${Uri.encodeComponent(rsvpUrl)}';
      final response = await http.get(Uri.parse(qrUrl));
      
      // Close loading dialog 
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (response.statusCode == 200) {
        // Create a blob with the correct MIME type
        final qrImageData = response.bodyBytes;
        // IMPORTANT: Create the blob with the correct MIME type
        final imageBlob = html.Blob([qrImageData], 'image/png');
        final imageUrl = html.Url.createObjectUrlFromBlob(imageBlob);
        
        // Create an anchor element for the download
        final imageAnchor = html.AnchorElement(href: imageUrl)
          ..setAttribute('download', fileName)
          ..style.display = 'none'
          ..click();
        
        // Add a slight delay before revoking the URL to ensure download starts
        Future.delayed(Duration(seconds: 1), () {
          html.Url.revokeObjectUrl(imageUrl);
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR code downloaded successfully'),
            backgroundColor: Colors.green[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        throw Exception('Failed to generate QR code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating QR code: $e')),
      );
    }
  } catch (e) {
    // Close loading dialog
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('Error generating QR code: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error generating QR code: $e')),
    );
  }
}
// Helper method to download QR code separately
// Helper method to download QR code separately
void _downloadQrCode(Uint8List qrImageData, String groupDesc) {
  try {
    // Create a blob with the correct MIME type
    final imageBlob = html.Blob([qrImageData], 'image/png');
    final imageUrl = html.Url.createObjectUrlFromBlob(imageBlob);
    
    // Create an anchor element for the download with proper styling
    final imageAnchor = html.AnchorElement(href: imageUrl)
      ..setAttribute('download', '${groupDesc.replaceAll(' ', '_')}_QR.png')
      ..style.display = 'none'
      ..click();
    
    // Add a slight delay before revoking the URL to ensure download starts
    Future.delayed(Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(imageUrl);
    });
  } catch (e) {
    print('Error downloading QR code: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error downloading QR code: $e')),
    );
  }
}

void _showDownloadOptions(String groupName, Function onPdfDownload, Function onQrImageDownload) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Download PDF'),
              onTap: () {
                Navigator.pop(context);
                onPdfDownload();
              },
            ),
            ListTile(
              leading: Icon(Icons.qr_code, color: Colors.green[700]),
              title: Text('Download QR Code Image'),
              onTap: () {
                Navigator.pop(context);
                onQrImageDownload();
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<Uint8List> _generateQrImage(String rsvpUrl) async {
  try {
    // Create a simpler QR painter with default settings
    final qrPainter = QrPainter(
      data: rsvpUrl,
      version: QrVersions.auto,
      color: Colors.black,
      emptyColor: Colors.white,
      gapless: true,
    );
    
    // Use a more conservative size
    final qrSize = 200.0;
    final imageSize = Size(qrSize, qrSize);
    
    // Generate the QR code
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Use a white background to ensure visibility
    canvas.drawRect(Rect.fromLTWH(0, 0, qrSize, qrSize), Paint()..color = Colors.white);
    qrPainter.paint(canvas, imageSize);
    final picture = recorder.endRecording();
    
    // Convert to image with explicit pixel ratio
    final img = await picture.toImage(qrSize.toInt(), qrSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      throw Exception('Failed to generate QR image: byteData is null');
    }
    
    return byteData.buffer.asUint8List();
  } catch (e) {
    print('Error in QR generation: $e');
    // Return a fallback - a simple white 1x1 pixel
    return Uint8List.fromList([255, 255, 255, 255]); // RGBA white pixel
  }
}

void _showFileOptions(File pdfFile, File qrImageFile, String groupName) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Open PDF'),
              onTap: () {
                Navigator.pop(context);
                OpenFile.open(pdfFile.path);
              },
            ),
            ListTile(
              leading: Icon(Icons.qr_code, color: Colors.green[700]),
              title: Text('Open QR Code Image'),
              onTap: () {
                Navigator.pop(context);
                OpenFile.open(qrImageFile.path);
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.blue),
              title: Text('Share PDF'),
              onTap: () {
                Navigator.pop(context);
                Share.shareFiles([pdfFile.path], text: 'Wedding RSVP for $groupName');
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.purple),
              title: Text('Share QR Code Image'),
              onTap: () {
                Navigator.pop(context);
                Share.shareFiles([qrImageFile.path], text: 'Wedding RSVP QR Code for $groupName');
              },
            ),
          ],
        ),
      );
    },
  );
}
 
  void _copyToClipboard(BuildContext context, String text) {
    if (!_isMounted || !mounted) return;
    
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('RSVP link copied to clipboard'),
        backgroundColor: Colors.green[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _signOut() async {
    try {
      await _auth.signOut();
      if (!_isMounted || !mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      print('Error signing out: $e');
    }
  }
  
  // Helper method to show AddGuestDialog
  void _showAddGuestDialog() {
    if (!_isMounted || !mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AddGuestDialog(
        onGuestAdded: () {
          if (_isMounted && mounted) {
            _loadRSVPData();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E9), // Very light green
              Color(0xFFC8E6C9), // Light green
              Color(0xFFF5F5F5), // Almost white
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _isLoading ? _buildLoadingIndicator() : _buildTabBar(),
              Expanded(
                child: _isLoading 
                  ? Container() 
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGroupsTab(),
                        _buildGuestsTab(),
                        _buildAttendingTab(),
                        _buildPendingTab(),
                        _buildDietaryTab(),
                        _buildSongRequestsAndNotesTab(),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGuestDialog,
        backgroundColor: Colors.green[400],
        child: Icon(Icons.add, color: Colors.white),
        elevation: 4,
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: Colors.green[100]!, width: 1),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite,
                    size: 24,
                    color: Colors.green[400],
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Kingsbury Wedding RSVP",
                    style: GoogleFonts.dancingScript(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.favorite,
                    size: 24,
                    color: Colors.green[400],
                  ),
                ],
              ),
              Text(
                "Dashboard",
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.green[400],
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Spacer(),
          _buildStatsCard(),
          SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.green[400]),
            onPressed: _loadRSVPData,
            tooltip: 'Refresh Data',
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.green[400]),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.only(top: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.green[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.green[700],
        labelStyle: GoogleFonts.lato(fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.lato(),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.green[400],
        ),
        tabs: [
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group),
                SizedBox(width: 8),
                Text("Groups"),
              ],
            ),
          ),
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person),
                SizedBox(width: 8),
                Text("All Guests"),
              ],
            ),
          ),
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle),
                SizedBox(width: 8),
                Text("Attending"),
              ],
            ),
          ),
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty),
                SizedBox(width: 8),
                Text("Pending"),
              ],
            ),
          ),
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant),
                SizedBox(width: 8),
                Text("Dietary Needs"),
              ],
            ),
          ),
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.comment),
                SizedBox(width: 8),
                Text("Notes & Songs"),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Column(
        children: [
          // Top row - Groups and guests
          Row(
            children: [
              Column(
                children: [
                  Text(
                    "$_totalGroups",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    "Groups",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Container(width: 1, height: 30, color: Colors.green[100]),
              SizedBox(width: 12),
              Column(
                children: [
                  Text(
                    "$_totalGuests",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[600],
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    "Guests",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 8),
          Divider(height: 1, color: Colors.green[100]),
          SizedBox(height: 8),
          
          // Bottom row - Responses
          Row(
            children: [
              Column(
                children: [
                  Text(
                    "$_attending",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    "Yes",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Container(width: 1, height: 30, color: Colors.green[100]),
              SizedBox(width: 12),
              Column(
                children: [
                  Text(
                    "$_notAttending",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[600],
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    "No",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[600],
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Container(width: 1, height: 30, color: Colors.green[100]),
              SizedBox(width: 12),
              Column(
                children: [
                  Text(
                    "$_pending",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[600],
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    "Pending",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Container(width: 1, height: 30, color: Colors.green[100]),
              SizedBox(width: 12),
              Column(
                children: [
                  Text(
                    "$_glutenFree",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    "GF",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
            ),
            SizedBox(height: 16),
            Text(
              "Loading guest data...",
              style: GoogleFonts.lato(
                color: Colors.green[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Tab content builders
  Widget _buildGroupsTab() {
    if (_groups.isEmpty) {
      return _buildEmptyState(
        message: "No groups added yet",
        icon: Icons.group_off,
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Groups & Families",
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _groups.length,
            itemBuilder: (context, index) {
              final group = _groups[index];
              final rsvpUrl = 'https://weddingp-9ffea.web.app/rsvp/${group['id']}';
              
              return _buildGroupCard(group, rsvpUrl);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildGuestsTab() {
    final allGuests = [..._attendingGuests, ..._notAttendingGuests, ..._pendingGuests];
    
    if (allGuests.isEmpty) {
      return _buildEmptyState(
        message: "No guests added yet",
        icon: Icons.person_off,
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "All Guests",
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: allGuests.length,
            itemBuilder: (context, index) {
              final guest = allGuests[index];
              return _buildGuestCard(guest);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildAttendingTab() {
    if (_attendingGuests.isEmpty) {
      return _buildEmptyState(
        message: "No confirmed attending guests yet",
        icon: Icons.event_busy,
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Attending Guests",
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _attendingGuests.length,
            itemBuilder: (context, index) {
              final guest = _attendingGuests[index];
              return _buildGuestCard(guest);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPendingTab() {
    if (_pendingGuests.isEmpty) {
      return _buildEmptyState(
        message: "No pending guests",
        icon: Icons.hourglass_empty,
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Pending Responses",
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingGuests.length,
            itemBuilder: (context, index) {
              final guest = _pendingGuests[index];
              return _buildGuestCard(guest);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildDietaryTab() {
    if (_glutenFreeGuests.isEmpty) {
      return _buildEmptyState(
        message: "No dietary requirements noted yet",
        icon: Icons.no_food,
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Dietary Requirements",
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _glutenFreeGuests.length,
            itemBuilder: (context, index) {
              final guest = _glutenFreeGuests[index];
              return _buildGuestCard(guest, showDietaryHighlight: true);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildSongRequestsAndNotesTab() {
    if (_songRequests.isEmpty && _groupNotes.isEmpty) {
      return _buildEmptyState(
        message: "No song requests or notes yet",
        icon: Icons.speaker_notes_off,
      );
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Song Requests Section
          if (_songRequests.isNotEmpty) ...[
            Text(
              "Song Requests",
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 16),
            ..._songRequests.map((group) => _buildDetailCard(
              title: group['groupName'],
              content: group['songRequest'],
              icon: Icons.music_note,
              iconColor: Colors.purple[600]!,
            )).toList(),
            SizedBox(height: 32),
          ],
          
          // Notes Section
          if (_groupNotes.isNotEmpty) ...[
            Text(
              "Notes from Guests",
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 16),
            ..._groupNotes.map((group) => _buildDetailCard(
              title: group['groupName'],
              content: group['notes'],
              icon: Icons.comment,
              iconColor: Colors.blue[600]!,
            )).toList(),
          ],
        ],
      ),
    );
  }
  
  // Helper widgets
  Widget _buildEmptyState({required String message, required IconData icon}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.green[100],
          ),
          SizedBox(height: 24),
          Text(
            message,
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[400],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text("Add Group"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[400],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
              shadowColor: Colors.green.withOpacity(0.5),
            ),
            onPressed: _showAddGuestDialog,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailCard({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.green[100]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGroupCard(Map<String, dynamic> group, String rsvpUrl) {
    // Calculate group stats
    final guests = group['guests'] as List<Map<String, dynamic>>;
    int attending = 0;
    int notAttending = 0;
    int pending = 0;
    
    for (var guest in guests) {
      final response = guest['response'];
      if (response == 'Yes') attending++;
      else if (response == 'No') notAttending++;
      else pending++;
    }
    
    // Format timestamp if available
    String timestampText = '';
    if (group['respondedAt'] != null) {
      final timestamp = group['respondedAt'] as Timestamp;
      final date = timestamp.toDate();
      timestampText = 'Updated on ${DateFormat.yMMMd().format(date)}';
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.green[100]!,
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          group['groupName'],
          style: GoogleFonts.lato(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            if (group['email'].toString().isNotEmpty)
              Text(
                group['email'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[600],
                ),
              ),
            SizedBox(height: 8),
            Row(
              children: [
                // Guest count badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.blue[400]),
                      SizedBox(width: 4),
                      Text(
                        "${guests.length} guests",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[400],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                
                // Response badges - Only show if there are guests with that response
                if (attending > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green[400]),
                        SizedBox(width: 4),
                        Text(
                          "$attending coming",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                if (notAttending > 0)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel, size: 16, color: Colors.red[400]),
                          SizedBox(width: 4),
                          Text(
                            "$notAttending declined",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.red[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            if (timestampText.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  timestampText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.copy, color: Colors.green[300]),
              tooltip: 'Copy RSVP Link',
              onPressed: () => _copyToClipboard(context, rsvpUrl),
            ),
            IconButton(
              icon: Icon(Icons.qr_code, color: Colors.green[300]),
              tooltip: 'Show QR Code',
              onPressed: () {
                if (!_isMounted || !mounted) return;
                
                showDialog(
                  context: context,
                  builder: (context) => _buildQRDialog(group['groupName'], rsvpUrl),
                );
              },
            ),
          ],
        ),
        // Expanded content with all guests
        children: [
          Divider(color: Colors.green[100]),
          SizedBox(height: 8),
          
          Text(
            "Guest Details",
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          SizedBox(height: 12),
          
          // List each guest in the group
          ...guests.map((guest) => _buildGroupGuestItem(guest)).toList(),
          
          SizedBox(height: 16),
          
          // Additional info section
          if (group['songRequest'].toString().isNotEmpty || group['notes'].toString().isNotEmpty) ...[
            Text(
              "Additional Information",
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 12),
            
            // Song Request
            if (group['songRequest'].toString().isNotEmpty)
              _buildInfoRow(
                icon: Icons.music_note,
                iconColor: Colors.purple[600]!,
                label: "Song Request",
                value: group['songRequest'],
              ),
              
            // Notes
            if (group['notes'].toString().isNotEmpty)
              _buildInfoRow(
                icon: Icons.note,
                iconColor: Colors.blue[600]!,
                label: "Additional Notes",
                value: group['notes'],
              ),
          ],
        ],
      ),
    );
  }
  
  // Individual guest item inside a group expansion panel
  Widget _buildGroupGuestItem(Map<String, dynamic> guest) {
    final name = guest['name'] ?? 'Guest';
    final response = guest['response'];
    final isGlutenIntolerant = guest['isGlutenIntolerant'] == true;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (response == 'Yes') {
      statusColor = Colors.green[600]!;
      statusIcon = Icons.check_circle;
      statusText = 'Attending';
    } else if (response == 'No') {
      statusColor = Colors.red[600]!;
      statusIcon = Icons.cancel;
      statusText = 'Not Attending';
    } else {
      statusColor = Colors.orange[600]!;
      statusIcon = Icons.help_outline;
      statusText = 'Pending';
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (response == 'Yes' && isGlutenIntolerant)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant, size: 12, color: Colors.amber[800]),
                  SizedBox(width: 4),
                  Text(
                    "Gluten-Free",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  // Individual guest card for the Guests tab and Attending tab
  Widget _buildGuestCard(DashboardGuest guest, {bool showDietaryHighlight = false}) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (guest.response == 'Yes') {
      statusColor = Colors.green[600]!;
      statusIcon = Icons.check_circle;
      statusText = 'Attending';
    } else if (guest.response == 'No') {
      statusColor = Colors.red[600]!;
      statusIcon = Icons.cancel;
      statusText = 'Not Attending';
    } else {
      statusColor = Colors.orange[600]!;
      statusIcon = Icons.help_outline;
      statusText = 'Pending';
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.green[100]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest.name,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        " • From: ${guest.groupName}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (guest.isGlutenIntolerant && (showDietaryHighlight || guest.response == 'Yes'))
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant, size: 12, color: Colors.amber[800]),
                    SizedBox(width: 4),
                    Text(
                      "Gluten-Free",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: Colors.grey[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
 Widget _buildQRDialog(String groupName, String rsvpUrl) {
  return Dialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    elevation: 8,
    child: Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "RSVP QR Code",
            style: GoogleFonts.dancingScript(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            "For $groupName",
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.green[600],
            ),
          ),
          SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[100]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: EdgeInsets.all(12),
            child: QRCodeGenerator(url: rsvpUrl),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    rsvpUrl,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 18, color: Colors.green[400]),
                  onPressed: () => _copyToClipboard(context, rsvpUrl),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.download, size: 18),
            label: Text("Download QR Code"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              _generateQrCodeOnly(groupName, rsvpUrl);
            },
          ),
          SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green[50],
              foregroundColor: Colors.green[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text("Close", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    ),
  );
}
  }


