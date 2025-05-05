import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';



class GuestRSVPPage extends StatefulWidget {
  final String rsvpId;

  GuestRSVPPage({Key? key, required this.rsvpId}) : super(key: key);

  @override
  _GuestRSVPPageState createState() => _GuestRSVPPageState();
}

class _GuestRSVPPageState extends State<GuestRSVPPage> with WidgetsBindingObserver {
  bool _isMounted = false;
  bool? _response;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _guestName;
  String? _errorMessage;
  bool _submitted = false;
  
  // Form fields
  final _notesController = TextEditingController();
  final _songRequestController = TextEditingController();
  bool _isGlutenIntolerant = false;

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
        _fetchGuestData();
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

  Future<void> _fetchGuestData() async {
    print('------------ FETCH GUEST DATA START ------------');
    print('Fetching guest data for RSVP ID: ${widget.rsvpId}');
    
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
      
      // Dump all keys and values for debugging
      print('Document fields:');
      data.forEach((key, value) {
        print('  $key: $value (${value?.runtimeType})');
      });
      
      // Extract fields with ultra-safe null handling
      final String guestName = (data['guestName'] ?? 'Guest').toString();
      final String? responseStr = data['response']?.toString();
      
      // Debug logging
      print('Guest name: $guestName');
      print('Response string: $responseStr');
      
      // Handle response value safely
      bool? responseValue = null;
      bool hasResponded = false;
      
      if (responseStr != null && responseStr != 'Pending') {
        responseValue = responseStr == 'Yes';
        hasResponded = true;
        print('Response value: $responseValue');
      } else {
        print('Response is Pending or null');
      }
      
      // Safely extract other form data with null checking
      final String notes = (data['notes'] ?? '').toString();
      final String songRequest = (data['songRequest'] ?? '').toString();
      final bool isGlutenIntolerant = data['isGlutenIntolerant'] == true;
      
      print('Notes: $notes');
      print('Song Request: $songRequest');
      print('Is Gluten Intolerant: $isGlutenIntolerant');
      
      // Check if still mounted before updating state
      if (!_isMounted || !mounted) {
        print('Widget is no longer mounted. Cannot update state.');
        return;
      }
      
      print('About to update state');
      // Update the UI state with safely extracted values
      try {
        setStateIfMounted(() {
          print("Setting _guestName to: $guestName");
          _guestName = guestName;
          
          print("Setting _response to: $responseValue");  
          _response = responseValue;
          
          print("Setting _submitted to: $hasResponded");
          _submitted = hasResponded;
          
          print("Setting _notesController.text to: $notes");
          _notesController.text = notes;
          
          print("Setting _songRequestController.text to: $songRequest");
          _songRequestController.text = songRequest;
          
          print("Setting _isGlutenIntolerant to: $isGlutenIntolerant");
          _isGlutenIntolerant = isGlutenIntolerant;
          
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
      
      print('Guest data loaded successfully');
      print('------------ FETCH GUEST DATA END ------------');
    } catch (e) {
      print('Unexpected error in _fetchGuestData: $e');
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

  Future<void> _submitRSVP(bool attending) async {
    print('------------ SUBMIT RSVP START ------------');
    print('Submitting RSVP: $attending');
    
    if (!_isMounted || !mounted) {
      print('Widget is not mounted. Cannot submit RSVP.');
      return;
    }
    
    setStateIfMounted(() {
      _isSubmitting = true;
      _response = attending;
    });
    
    try {
      final Map<String, dynamic> updateData = {
        'response': attending ? 'Yes' : 'No',
        'respondedAt': FieldValue.serverTimestamp(),
        'notes': _notesController.text,
        'songRequest': _songRequestController.text,
        'isGlutenIntolerant': _isGlutenIntolerant,
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
                onPressed: _fetchGuestData,
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
            
            // Guest name
            Text(
              "Dear $_guestName,",
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
                "Will you join us on our special day?",
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              
              // Response buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Yes button
                  ElevatedButton(
                    onPressed: _isSubmitting 
                        ? null 
                        : () => setStateIfMounted(() { _response = true; }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _response == true ? Colors.green[400] : Colors.grey[300],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                      shadowColor: Colors.green.withOpacity(0.4),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Joyfully Accept",
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  
                  // No button
                  OutlinedButton(
                    onPressed: _isSubmitting 
                        ? null 
                        : () => setStateIfMounted(() { _response = false; }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _response == false ? Colors.red[700] : Colors.grey[700],
                      backgroundColor: _response == false ? Colors.red[50] : Colors.transparent,
                      side: BorderSide(
                        color: _response == false ? Colors.red[300]! : Colors.grey[400]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cancel_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Regretfully Decline",
                          style: GoogleFonts.lato(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Show additional fields if they've made a selection
              if (_response != null) ...[
                SizedBox(height: 32),
                
                // Divider with text
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
                
                // Only show these fields if attending
                if (_response == true) ...[
                  // Dietary Requirements - Gluten Intolerance Checkbox
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green[200]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.green[50],
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Dietary Requirements",
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: _isGlutenIntolerant,
                              onChanged: (value) {
                                setStateIfMounted(() {
                                  _isGlutenIntolerant = value ?? false;
                                });
                              },
                              activeColor: Colors.green[400],
                            ),
                            Text(
                              "I require gluten-free options",
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                
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
                        : () => _submitRSVP(_response!),
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
              ],
              
              // Loading indicator
              if (_isSubmitting)
                Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                  ),
                ),
            ] else ...[
              // Response feedback
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _response == true 
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _response == true 
                        ? Colors.green[200]!
                        : Colors.red[200]!,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _response == true ? Icons.favorite : Icons.heart_broken,
                      color: _response == true ? Colors.green[600] : Colors.red[600],
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _response == true
                          ? "We're delighted you'll be joining us!"
                          : "We're sorry you won't be able to join us.",
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: _response == true ? Colors.green[800] : Colors.red[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _response == true
                          ? "We can't wait to celebrate with you."
                          : "You'll be missed on our special day.",
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: _response == true ? Colors.green[700] : Colors.red[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Show submitted information if attending
              if (_response == true) ...[
                SizedBox(height: 24),
                
                // Submitted Info Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                      Text(
                        "Your Submitted Information",
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      
                      // Dietary Requirements
                      if (_isGlutenIntolerant) ...[
                        _buildInfoRow(
                          icon: Icons.restaurant,
                          label: "Dietary Requirements",
                          value: "Gluten-free options requested",
                        ),
                        SizedBox(height: 12),
                      ],
                      
                      // Song Request
                      if (_songRequestController.text.isNotEmpty) ...[
                        _buildInfoRow(
                          icon: Icons.music_note,
                          label: "Song Request",
                          value: _songRequestController.text,
                        ),
                        SizedBox(height: 12),
                      ],
                      
                      // Notes
                      if (_notesController.text.isNotEmpty) ...[
                        _buildInfoRow(
                          icon: Icons.note,
                          label: "Additional Notes",
                          value: _notesController.text,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              
              SizedBox(height: 24),
              
              // Change response button
              TextButton.icon(
                icon: Icon(Icons.edit, size: 18),
                label: Text("Change my response"),
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
  
  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.green[400]),
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