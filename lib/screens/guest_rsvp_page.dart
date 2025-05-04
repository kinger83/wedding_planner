import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class GuestRSVPPage extends StatefulWidget {
  final String rsvpId;

  GuestRSVPPage({Key? key, required this.rsvpId}) : super(key: key);

  @override
  _GuestRSVPPageState createState() => _GuestRSVPPageState();
}

class _GuestRSVPPageState extends State<GuestRSVPPage> with SingleTickerProviderStateMixin {
  bool? _response;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _guestName;
  String? _errorMessage;
  bool _submitted = false;
  
  // New form fields
  final _notesController = TextEditingController();
  final _songRequestController = TextEditingController();
  bool _isGlutenIntolerant = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _fetchGuestData();
    
    // Set up animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    _songRequestController.dispose();
    super.dispose();
  }

  Future<void> _fetchGuestData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rsvps')
          .doc(widget.rsvpId)
          .get();
          
      if (!doc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid RSVP link. Please contact the couple.';
        });
        return;
      }
      
      final data = doc.data();
      
      setState(() {
        _guestName = data?['guestName'];
        // If already responded, show the response
        if (data?['response'] != null) {
          _response = data?['response'] == 'Yes';
          
          // Load previous responses if available
          if (data?['notes'] != null) {
            _notesController.text = data?['notes'];
          }
          if (data?['songRequest'] != null) {
            _songRequestController.text = data?['songRequest'];
          }
          if (data?['isGlutenIntolerant'] != null) {
            _isGlutenIntolerant = data?['isGlutenIntolerant'];
          }
          
          _submitted = true;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading RSVP: ${e.toString()}';
      });
    }
  }

  Future<void> _submitRSVP(bool attending) async {
    setState(() {
      _isSubmitting = true;
      _response = attending;
    });
    
    try {
      await FirebaseFirestore.instance
          .collection('rsvps')
          .doc(widget.rsvpId)
          .update({
            'response': attending ? 'Yes' : 'No',
            'respondedAt': FieldValue.serverTimestamp(),
            'notes': _notesController.text,
            'songRequest': _songRequestController.text,
            'isGlutenIntolerant': _isGlutenIntolerant,
          });
          
      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Error submitting RSVP: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?ixlib=rb-1.2.1&auto=format&fit=crop&w=1352&q=80'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.7),
              BlendMode.lighten,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 500),
                  margin: EdgeInsets.all(24.0),
                  child: Card(
                    elevation: 8,
                    shadowColor: Colors.green.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: _buildContent(),
                    ),
                  ),
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
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 64),
          SizedBox(height: 24),
          Text(
            _errorMessage!,
            style: GoogleFonts.lato(
              fontSize: 18,
              color: Colors.red[700],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          OutlinedButton.icon(
            icon: Icon(Icons.mail),
            label: Text("Contact Couple"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green[700],
              side: BorderSide(color: Colors.green[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              // Add contact functionality here
            },
          ),
        ],
      );
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Decorative elements
        _buildDecorativeHeader(),
        SizedBox(height: 16),
        
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
                    : () => setState(() { _response = true; }),
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
                    : () => setState(() { _response = false; }),
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
                            setState(() {
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
              setState(() {
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
          "The Soon-to-be-Weds",
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
  
  Widget _buildDecorativeHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.favorite, size: 16, color: Colors.green[300]),
        SizedBox(width: 8),
        Container(
          width: 40,
          height: 1,
          color: Colors.green[200],
        ),
        SizedBox(width: 8),
        Icon(Icons.favorite, size: 24, color: Colors.green[400]),
        SizedBox(width: 8),
        Container(
          width: 40,
          height: 1,
          color: Colors.green[200],
        ),
        SizedBox(width: 8),
        Icon(Icons.favorite, size: 16, color: Colors.green[300]),
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
  }
}