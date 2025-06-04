import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Guest model to represent each individual in a group
class Guest {
  String name;
  String? response; // Yes, No, or null for not answered
  bool isGlutenIntolerant;
  
  Guest({
    required this.name,
    this.response,
    this.isGlutenIntolerant = false,
  });
  
  // Create from Firestore data
  factory Guest.fromMap(Map<String, dynamic> map) {
    return Guest(
      name: map['name'] ?? '',
      response: map['response'],
      isGlutenIntolerant: map['isGlutenIntolerant'] ?? false,
    );
  }
  
  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'response': response,
      'isGlutenIntolerant': isGlutenIntolerant,
    };
  }
}

class GuestRSVPPage extends StatefulWidget {
  final String rsvpId;

  GuestRSVPPage({Key? key, required this.rsvpId}) : super(key: key);

  @override
  _GuestRSVPPageState createState() => _GuestRSVPPageState();
}

class _GuestRSVPPageState extends State<GuestRSVPPage> with WidgetsBindingObserver {
  bool _isMounted = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _submitted = false;
  
  // Group details
  String? _groupName;
  List<Guest> _guests = [];
  
  // Form fields
  final _notesController = TextEditingController();
  final _songRequestController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _isMounted = true;
    WidgetsBinding.instance.addObserver(this);
    print('################################');
    print('GuestRSVPPage initialized with RSVP ID: ${widget.rsvpId}');
    
    // Force logout any user when this page loads
    _logoutAnyUser();
    
    // Use proper frame callback instead of arbitrary delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted && mounted) {
        print('################################');
        print('Starting data fetch after frame rendered - RSVP ID: ${widget.rsvpId}');
        print('Current route after frame: ${ModalRoute.of(context)?.settings.name}');
        print('################################');
        _fetchGroupData();
      }
    });
  }
  
  // Add this method to force logout any currently logged in user
  Future<void> _logoutAnyUser() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('Found logged in user, logging out before showing RSVP page');
        await FirebaseAuth.instance.signOut();
        print('User logged out successfully');
      } else {
        print('No user logged in, continuing to RSVP page');
      }
    } catch (e) {
      print('Error during logout: $e');
      // Continue even if logout fails
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('################################');
    print('didChangeDependencies called - RSVP ID: ${widget.rsvpId}');
    print('Current route: ${ModalRoute.of(context)?.settings.name}');
    print('################################');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('################################');
    print('Lifecycle state changed to: $state - RSVP ID: ${widget.rsvpId}');
    print('################################');
  }

  @override
  void dispose() {
    print('################################');
    print('GuestRSVPPage disposing - RSVP ID: ${widget.rsvpId}');
    print('################################');
    _isMounted = false;
    WidgetsBinding.instance.removeObserver(this);
    _notesController.dispose();
    _songRequestController.dispose();
    super.dispose();
  }
  
  // Safe setState alternative
  void setStateIfMounted(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _fetchGroupData() async {
    print('------------ FETCH GROUP DATA START ------------');
    print('Fetching group data for RSVP ID: ${widget.rsvpId}');
    
    try {
      if (!_isMounted || !mounted) {
        print('Widget is not mounted. Stopping data fetch.');
        return;
      }
      
      setStateIfMounted(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Get the document
      print('Getting Firestore document for RSVP ID: ${widget.rsvpId}');
      
      // Use a try-catch specifically for the Firestore call
      DocumentSnapshot? doc;
      try {
        doc = await FirebaseFirestore.instance
            .collection('rsvps')
            .doc(widget.rsvpId)
            .get();
        print('Document retrieved successfully');
      } catch (e) {
        print('Error getting document: $e');
        if (!_isMounted || !mounted) return;
        setStateIfMounted(() {
          _isLoading = false;
          _errorMessage = 'Error retrieving RSVP data: $e';
        });
        // Don't navigate away, just stay on page with error
        return;
      }
      
      // Check if doc exists (use null-safe check)
      if (doc == null || !doc.exists) {
        print('Document does not exist');
        if (!_isMounted || !mounted) return;
        setStateIfMounted(() {
          _isLoading = false;
          _errorMessage = 'RSVP not found. Please contact the couple.';
        });
        return;
      }
      
      // Safely get data with robust null handling
      Map<String, dynamic>? data;
      try {
        data = doc.data() as Map<String, dynamic>?;
        print('Document data cast successfully');
      } catch (e) {
        print('Error casting document data: $e');
        if (!_isMounted || !mounted) return;
        setStateIfMounted(() {
          _isLoading = false;
          _errorMessage = 'Error processing RSVP data: $e';
        });
        return;
      }
      
      // Log the data for debugging
      print('Document data: $data');
      
      // Check if data is null
      if (data == null) {
        print('Document data is null');
        if (!_isMounted || !mounted) return;
        setStateIfMounted(() {
          _isLoading = false;
          _errorMessage = 'RSVP data is empty. Please contact the couple.';
        });
        return;
      }
      
      // Extract group name
      final String groupName = (data['groupName'] ?? 'Guest Group').toString();
      
      // Extract notes and song request
      final String notes = (data['notes'] ?? '').toString();
      final String songRequest = (data['songRequest'] ?? '').toString();
      
      // Extract guest list
      List<Guest> guests = [];
      bool hasResponded = false;
      
      // Handle both old format (single guest) and new format (multiple guests)
      if (data.containsKey('guests') && data['guests'] is List) {
        // New format with multiple guests
        final guestsList = data['guests'] as List;
        for (var guestData in guestsList) {
          if (guestData is Map<String, dynamic>) {
            final guest = Guest.fromMap(guestData);
            guests.add(guest);
            
            // Check if any guest has responded
            if (guest.response != null && guest.response != 'Pending') {
              hasResponded = true;
            }
          }
        }
      } else {
        // Legacy format - single guest
        final guestName = (data['guestName'] ?? 'Guest').toString();
        final responseStr = data['response']?.toString();
        final isGlutenIntolerant = data['isGlutenIntolerant'] == true;
        
        final guest = Guest(
          name: guestName,
          response: responseStr,
          isGlutenIntolerant: isGlutenIntolerant,
        );
        
        guests.add(guest);
        
        if (responseStr != null && responseStr != 'Pending') {
          hasResponded = true;
        }
      }
      
      // If no guests found, create a placeholder
      if (guests.isEmpty) {
        guests.add(Guest(name: 'Guest'));
      }
      
      // Check if still mounted before updating state
      if (!_isMounted || !mounted) {
        print('Widget is no longer mounted. Cannot update state.');
        return;
      }
      
      print('About to update state');
      // Update the UI state with safely extracted values
      try {
        setStateIfMounted(() {
          print("Setting _groupName to: $groupName");
          _groupName = groupName;
          
          print("Setting _guests to: ${guests.length} guests");
          _guests = guests;
          
          print("Setting _submitted to: $hasResponded");
          _submitted = hasResponded;
          
          print("Setting _notesController.text to: $notes");
          _notesController.text = notes;
          
          print("Setting _songRequestController.text to: $songRequest");
          _songRequestController.text = songRequest;
          
          print("Setting _isLoading to: false");
          _isLoading = false;
        });
        print("State updated successfully");
      } catch (stateError) {
        print('Error during setState: $stateError');
        if (stateError is Error && stateError.stackTrace != null) {
          print('setState stack trace: ${stateError.stackTrace}');
        }
        
        // Try a minimal state update as fallback
        if (_isMounted && mounted) {
          setStateIfMounted(() {
            _isLoading = false;
            _errorMessage = 'Error updating UI: $stateError';
          });
        }
      }
      
      print('Group data loaded successfully');
      print('------------ FETCH GROUP DATA END ------------');
    } catch (e) {
      print('Unexpected error in _fetchGroupData: $e');
      print(e.toString());
      if (e is Error && e.stackTrace != null) {
        print('Stack trace: ${e.stackTrace}');
      }
      
      if (_isMounted && mounted) {
        setStateIfMounted(() {
          _isLoading = false;
          _errorMessage = 'Unexpected error: $e';
        });
      }
    }
  }

  Future<void> _submitRSVP() async {
    print('------------ SUBMIT RSVP START ------------');
    
    if (!_isMounted || !mounted) {
      print('Widget is not mounted. Cannot submit RSVP.');
      return;
    }
    
    // Check if at least one guest has responded
    bool anyResponded = _guests.any((guest) => guest.response != null);
    if (!anyResponded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please indicate who can attend for at least one guest'),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }
    
    setStateIfMounted(() {
      _isSubmitting = true;
    });
    
    try {
      // Convert guest list to a format suitable for Firestore
      final List<Map<String, dynamic>> guestsData = _guests.map((guest) => guest.toMap()).toList();
      
      final Map<String, dynamic> updateData = {
        'guests': guestsData,
        'respondedAt': FieldValue.serverTimestamp(),
        'notes': _notesController.text,
        'songRequest': _songRequestController.text,
      };
      
      print('Updating document with data: $updateData');
      
      await FirebaseFirestore.instance
          .collection('rsvps')
          .doc(widget.rsvpId)
          .update(updateData);
          
      print('RSVP submitted successfully');
      
      if (!_isMounted || !mounted) {
        print('Widget unmounted after RSVP submission');
        return;
      }
      
      setStateIfMounted(() {
        _isSubmitting = false;
        _submitted = true;
      });
      print('------------ SUBMIT RSVP END ------------');
    } catch (e) {
      print('Error submitting RSVP: $e');
      if (e is Error && e.stackTrace != null) {
        print('Stack trace: ${e.stackTrace}');
      }
      
      if (_isMounted && mounted) {
        setStateIfMounted(() {
          _isSubmitting = false;
          _errorMessage = 'Error submitting RSVP: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("################################");
    print("Building GuestRSVPPage for ID: ${widget.rsvpId}");
    print("Current route in build: ${ModalRoute.of(context)?.settings.name}");
    print("################################");
    
    // Make sure this page doesn't disappear
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('Post frame callback - still on RSVP page');
      print("Current route in post frame: ${ModalRoute.of(context)?.settings.name}");
    });
    
    // To prevent back navigation, use PopScope (newer Flutter versions)
    return PopScope(
      canPop: false, // This prevents the user from popping this route
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Wedding RSVP',
            style: GoogleFonts.dancingScript(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          automaticallyImplyLeading: false, // Remove back button
          backgroundColor: Colors.green[400],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: Colors.green[50],
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 500),
                  margin: EdgeInsets.all(24.0),
                  child: _buildContent(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
            ),
            SizedBox(height: 24),
            Text(
              "Loading your invitation...",
              style: GoogleFonts.lato(
                fontSize: 16,
                color: Colors.green[400],
              ),
            ),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 64),
              SizedBox(height: 24),
              Text(
                "There was a problem",
                style: GoogleFonts.lato(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Text(
                "Please contact the couple or try again later.",
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchGroupData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[400],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text("Try Again"),
              ),
              SizedBox(height: 16),
              // Debug info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Debug Info:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "RSVP ID: ${widget.rsvpId}",
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
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
    
    // If no errors, show the actual RSVP form
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Wedding title
            Text(
              "You're Invited",
              style: GoogleFonts.dancingScript(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            
            // Divider
            Container(
              width: 100,
              height: 2,
              color: Colors.green[200],
            ),
            SizedBox(height: 32),
            
            // Group name
            Text(
              "Dear ${_groupName},",
              style: GoogleFonts.lato(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.green[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            // Invitation text
            Text(
              _submitted
                  ? "Thank you for your response!"
                  : "We request the pleasure of your company at our wedding celebration.",
              style: GoogleFonts.lato(
                fontSize: 18,
                height: 1.5,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            
            // RSVP Form Section
            if (!_submitted) ...[
              Text(
                "Please let us know who will be joining us on our special day:",
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              
              // Guest Response Section - List all guests with response options
              ..._buildGuestResponseSections(),
              
              SizedBox(height: 32),
              
              // Additional Information Section
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.green[200]),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Additional Information",
                      style: GoogleFonts.lato(
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.green[200]),
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // Song Request Field
              TextField(
                controller: _songRequestController,
                decoration: InputDecoration(
                  labelText: 'Song Request',
                  labelStyle: TextStyle(color: Colors.green[600]),
                  hintText: 'What song would you like to hear at our celebration?',
                  prefixIcon: Icon(Icons.music_note, color: Colors.green[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[400]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 1,
              ),
              SizedBox(height: 16),
              
              // Notes Field
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Additional Notes',
                  labelStyle: TextStyle(color: Colors.green[600]),
                  hintText: 'Any additional information you would like us to know...',
                  prefixIcon: Icon(Icons.note, color: Colors.green[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[400]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),
              SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting 
                      ? null 
                      : () => _submitRSVP(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[500],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: _isSubmitting
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        )
                      : Text(
                          'Submit RSVP',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              
              // Loading indicator
              if (_isSubmitting)
                Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                  ),
                ),
            ] else ...[
              // Response summary after submission
              _buildResponseSummary(),
              
              SizedBox(height: 24),
              
              // Change response button
              TextButton.icon(
                icon: Icon(Icons.edit, size: 18),
                label: Text("Change our response"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () {
                  setStateIfMounted(() {
                    _submitted = false;
                  });
                },
              ),
            ],
            
            SizedBox(height: 32),
            
            // Footer
            Text(
              "With love,",
              style: GoogleFonts.dancingScript(
                fontSize: 20,
                color: Colors.green[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              "Kirsty & Jason",
              style: GoogleFonts.dancingScript(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            
            // Bottom decorative element
            _buildDecorativeFooter(),
          ],
        ),
      ),
    );
  }
  
  // Builds response sections for each guest
  List<Widget> _buildGuestResponseSections() {
    List<Widget> sections = [];
    
    for (int i = 0; i < _guests.length; i++) {
      final guest = _guests[i];
      
      sections.add(
        Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guest.name,
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              SizedBox(height: 12),
              
              // Response buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setStateIfMounted(() { 
                          _guests[i].response = 'Yes';
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: guest.response == 'Yes' ? Colors.green[400] : Colors.grey[300],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Will Attend'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setStateIfMounted(() { 
                          _guests[i].response = 'No';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: guest.response == 'No' ? Colors.red[700] : Colors.grey[700],
                        backgroundColor: guest.response == 'No' ? Colors.red[50] : Colors.transparent,
                        side: BorderSide(
                          color: guest.response == 'No' ? Colors.red[300]! : Colors.grey[400]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Cannot Attend'),
                    ),
                  ),
                ],
              ),
              
              // Only show dietary requirements if attending
              if (guest.response == 'Yes') ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: guest.isGlutenIntolerant,
                      onChanged: (value) {
                        setStateIfMounted(() {
                          _guests[i].isGlutenIntolerant = value ?? false;
                        });
                      },
                      activeColor: Colors.green[400],
                    ),
                    Text(
                      "Requires gluten-free options",
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    return sections;
  }
  
  // Build response summary after submission
Widget _buildResponseSummary() {
  // Count attendees and regrets
  int attending = 0;
  int notAttending = 0;
  int totalResponded = 0;
  
  for (var guest in _guests) {
    if (guest.response == 'Yes') attending++;
    else if (guest.response == 'No') notAttending++;
    
    // Count total guests who have responded (either Yes or No)
    if (guest.response == 'Yes' || guest.response == 'No') {
      totalResponded++;
    }
  }
  
  // Determine the correct message based on attendance numbers
  String attendanceMessage = "";
  if (attending == 0 && _guests.length == 1){
    attendanceMessage = "We are sorry you will not be able to join us.";
  } else if (attending == 0) {
    attendanceMessage = "We're sorry that none of your group will be able to join us.";
  } else if (attending == _guests.length && _guests.length > 1) {
    attendanceMessage = "We're delighted that everyone in your group will be joining us.";
  } else if (attending == 1 && _guests.length == 1) {
    attendanceMessage = "We're delighted that you will be joining us.";
  } else {
    attendanceMessage = "We're delighted that some of your group will be joining us.";
  }
  
  return Column(
    children: [
      // Summary header
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green[600],
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              "Your RSVP has been received!",
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.green[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              attendanceMessage,
              style: GoogleFonts.lato(
                fontSize: 16,
                color: attending > 0 ? Colors.green[700] : Colors.red[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      SizedBox(height: 24),
      
      // Individual responses
      Text(
        "Your Response Details",
        style: GoogleFonts.lato(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green[800],
        ),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 16),
      
      // List of guests with responses
      ...(_guests.map((guest) => _buildGuestResponseItem(guest)).toList()),
      
      // Additional info summary
      if (_notesController.text.isNotEmpty || _songRequestController.text.isNotEmpty) ...[
        SizedBox(height: 24),
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
              if (_songRequestController.text.isNotEmpty) ...[
                _buildInfoRow(
                  icon: Icons.music_note,
                  label: "Song Request",
                  value: _songRequestController.text,
                  iconColor: Colors.purple[600]!,
                ),
                SizedBox(height: 12),
              ],
              
              if (_notesController.text.isNotEmpty)
                _buildInfoRow(
                  icon: Icons.note,
                  label: "Additional Notes",
                  value: _notesController.text,
                  iconColor: Colors.blue[600]!,
                ),
            ],
          ),
        ),
      ],
    ],
  );
}
  // Helper to build individual guest response item
  Widget _buildGuestResponseItem(Guest guest) {
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
      statusColor = Colors.grey[600]!;
      statusIcon = Icons.help;
      statusText = 'No Response';
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
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
            child: Icon(statusIcon, color: statusColor, size: 24),
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
                    fontWeight: FontWeight.bold,
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
          if (guest.response == 'Yes' && guest.isGlutenIntolerant)
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
  
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value
  }) {
    return Row(
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
    );
  }
  
  Widget _buildDecorativeFooter() {
    return Container(
      width: double.infinity,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.green[100]!,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10),
          color: Colors.white,
          child: Text(
            "Forever & Always",
            style: GoogleFonts.dancingScript(
              fontSize: 16,
              color: Colors.green[400],
            ),
          ),
        ),
      ),
    );
  }}
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
  
  // List to store guest names
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
  

