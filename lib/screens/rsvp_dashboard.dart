import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wedding_app/utils/qr_code_generator.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RSVPDashboard extends StatefulWidget {
  RSVPDashboard({Key? key}) : super(key: key);

  @override
  _RSVPDashboardState createState() => _RSVPDashboardState();
}

class _RSVPDashboardState extends State<RSVPDashboard> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  int _attending = 0;
  int _notAttending = 0;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final snapshot = await _firestore.collection('rsvps').get();
    int attending = 0;
    int notAttending = 0;
    int pending = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['response'] == 'Yes') {
        attending++;
      } else if (data['response'] == 'No') {
        notAttending++;
      } else {
        pending++;
      }
    }

    setState(() {
      _attending = attending;
      _notAttending = notAttending;
      _pending = pending;
      _isLoading = false;
    });
  }

  void _copyToClipboard(BuildContext context, String text) {
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
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/');
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
              Expanded(
                child: _isLoading ? _buildLoadingIndicator() : _buildDashboardContent(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddGuestDialog(
              onGuestAdded: () {
                _loadStats();
              },
            ),
          );
        },
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
                    "Wedding RSVP",
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
            icon: Icon(Icons.logout, color: Colors.green[400]),
            onPressed: _signOut,
            tooltip: 'Sign Out',
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
      child: Row(
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
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
          ),
          SizedBox(height: 16),
          Text(
            "Loading your guest list...",
            style: GoogleFonts.lato(
              color: Colors.green[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "Guest RSVP Status",
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('rsvps').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              
              final rsvps = snapshot.data!.docs;
              
              if (rsvps.isEmpty) {
                return _buildEmptyState();
              }
              
              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: rsvps.length,
                itemBuilder: (context, index) {
                  final rsvp = rsvps[index];
                  final rsvpUrl = 'https://weddingp-9ffea.web.app/rsvp/${rsvp.id}';
                  
                  return _buildGuestCard(rsvp, rsvpUrl);
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.green[100],
          ),
          SizedBox(height: 24),
          Text(
            "No Guests Added Yet",
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[400],
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Add your first guest using the + button",
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.green[600],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text("Add Guest"),
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
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AddGuestDialog(
                  onGuestAdded: () {
                    _loadStats();
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildGuestCard(DocumentSnapshot rsvp, String rsvpUrl) {
    final data = rsvp.data() as Map<String, dynamic>;
    final guestName = data['guestName'] ?? 'Guest';
    final response = data['response'];
    final email = data['email'] ?? 'Not provided';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (response == 'Yes') {
      statusColor = Colors.green[600]!;
      statusText = 'Attending';
      statusIcon = Icons.check_circle;
    } else if (response == 'No') {
      statusColor = Colors.red[600]!;
      statusText = 'Not Attending';
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange[600]!;
      statusText = 'Pending Response';
      statusIcon = Icons.access_time;
    }
    
    // Format timestamp if available
    String timestampText = '';
    if (data['respondedAt'] != null) {
      final timestamp = data['respondedAt'] as Timestamp;
      final date = timestamp.toDate();
      timestampText = 'Responded on ${DateFormat.yMMMd().format(date)}';
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
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(
              guestName,
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
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[600],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (timestampText.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      timestampText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[500],
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
                    showDialog(
                      context: context,
                      builder: (context) => _buildQRDialog(guestName, rsvpUrl),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQRDialog(String guestName, String rsvpUrl) {
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
              "For $guestName",
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
            SizedBox(
              width: double.infinity,
              child: TextButton(
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
            ),
          ],
        ),
      ),
    );
  }
}

class AddGuestDialog extends StatefulWidget {
  final Function? onGuestAdded;

  AddGuestDialog({this.onGuestAdded});

  @override
  _AddGuestDialogState createState() => _AddGuestDialogState();
}

class _AddGuestDialogState extends State<AddGuestDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isAdding = false;

  Future<void> _addGuest() async {
    if (_nameController.text.isEmpty) return;
    
    setState(() {
      _isAdding = true;
    });
    
    try {
      await FirebaseFirestore.instance.collection('rsvps').add({
        'guestName': _nameController.text,
        'email': _emailController.text,
        'response': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      Navigator.pop(context);
      
      if (widget.onGuestAdded != null) {
        widget.onGuestAdded!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding guest: $e')),
      );
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
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
              "Add New Guest",
              style: GoogleFonts.dancingScript(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Guest Name',
                labelStyle: TextStyle(color: Colors.green[300]),
                prefixIcon: Icon(Icons.person, color: Colors.green[300]),
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
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email (optional)',
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green[200]!),
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
                    onPressed: _isAdding ? null : _addGuest,
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
                        : Text("Add Guest", style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:wedding_app/utils/qr_code_generator.dart';
// import 'package:flutter/services.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';

// class RSVPDashboard extends StatefulWidget {
//   RSVPDashboard({Key? key}) : super(key: key);

//   @override
//   _RSVPDashboardState createState() => _RSVPDashboardState();
// }

// class _RSVPDashboardState extends State<RSVPDashboard> {
//   final _firestore = FirebaseFirestore.instance;
//   final _auth = FirebaseAuth.instance;
//   bool _isLoading = true;
//   int _attending = 0;
//   int _notAttending = 0;
//   int _pending = 0;

//   @override
//   void initState() {
//     super.initState();
//     _loadStats();
//   }

//   Future<void> _loadStats() async {
//     final snapshot = await _firestore.collection('rsvps').get();
//     int attending = 0;
//     int notAttending = 0;
//     int pending = 0;

//     for (var doc in snapshot.docs) {
//       final data = doc.data();
//       if (data['response'] == 'Yes') {
//         attending++;
//       } else if (data['response'] == 'No') {
//         notAttending++;
//       } else {
//         pending++;
//       }
//     }

//     setState(() {
//       _attending = attending;
//       _notAttending = notAttending;
//       _pending = pending;
//       _isLoading = false;
//     });
//   }

//   void _copyToClipboard(BuildContext context, String text) {
//     Clipboard.setData(ClipboardData(text: text));
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('RSVP link copied to clipboard'),
//         backgroundColor: Colors.pink[400],
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//     );
//   }

//   void _signOut() async {
//     await _auth.signOut();
//     Navigator.pushReplacementNamed(context, '/');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color(0xFFFCE4EC), // Very light pink
//               Colors.white,
//               Color(0xFFF8BBD0), // Light pink
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               _buildAppBar(),
//               Expanded(
//                 child: _isLoading ? _buildLoadingIndicator() : _buildDashboardContent(),
//               ),
//             ],
//           ),
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           showDialog(
//             context: context,
//             builder: (context) => AddGuestDialog(
//               onGuestAdded: () {
//                 _loadStats();
//               },
//             ),
//           );
//         },
//         backgroundColor: Colors.pink[400],
//         child: Icon(Icons.add, color: Colors.white),
//         elevation: 4,
//       ),
//     );
//   }

//   Widget _buildAppBar() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.pink.withOpacity(0.1),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(20),
//           bottomRight: Radius.circular(20),
//         ),
//       ),
//       child: Row(
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Wedding RSVP",
//                 style: GoogleFonts.dancingScript(
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.pink[700],
//                 ),
//               ),
//               Text(
//                 "Dashboard",
//                 style: GoogleFonts.lato(
//                   fontSize: 14,
//                   color: Colors.grey[600],
//                   letterSpacing: 2,
//                 ),
//               ),
//             ],
//           ),
//           Spacer(),
//           _buildStatsCard(),
//           SizedBox(width: 16),
//           IconButton(
//             icon: Icon(Icons.logout, color: Colors.pink[400]),
//             onPressed: _signOut,
//             tooltip: 'Sign Out',
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStatsCard() {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.pink[50],
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: Colors.pink[100]!),
//       ),
//       child: Row(
//         children: [
//           Column(
//             children: [
//               Text(
//                 "$_attending",
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.green[600],
//                   fontSize: 20,
//                 ),
//               ),
//               Text(
//                 "Yes",
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.green[600],
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(width: 12),
//           Container(width: 1, height: 30, color: Colors.pink[100]),
//           SizedBox(width: 12),
//           Column(
//             children: [
//               Text(
//                 "$_notAttending",
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.red[600],
//                   fontSize: 20,
//                 ),
//               ),
//               Text(
//                 "No",
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.red[600],
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(width: 12),
//           Container(width: 1, height: 30, color: Colors.pink[100]),
//           SizedBox(width: 12),
//           Column(
//             children: [
//               Text(
//                 "$_pending",
//                 style: TextStyle(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.orange[600],
//                   fontSize: 20,
//                 ),
//               ),
//               Text(
//                 "Pending",
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.orange[600],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingIndicator() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[400]!),
//           ),
//           SizedBox(height: 16),
//           Text(
//             "Loading your guest list...",
//             style: GoogleFonts.lato(
//               color: Colors.pink[400],
//               fontSize: 16,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDashboardContent() {
//     return Column(
//       children: [
//         Padding(
//           padding: EdgeInsets.all(20),
//           child: Text(
//             "Guest RSVP Status",
//             style: GoogleFonts.lato(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.pink[800],
//             ),
//           ),
//         ),
        
//         Expanded(
//           child: StreamBuilder<QuerySnapshot>(
//             stream: _firestore.collection('rsvps').snapshots(),
//             builder: (context, snapshot) {
//               if (!snapshot.hasData) {
//                 return Center(child: CircularProgressIndicator());
//               }
              
//               final rsvps = snapshot.data!.docs;
              
//               if (rsvps.isEmpty) {
//                 return _buildEmptyState();
//               }
              
//               return ListView.builder(
//                 padding: EdgeInsets.symmetric(horizontal: 16),
//                 itemCount: rsvps.length,
//                 itemBuilder: (context, index) {
//                   final rsvp = rsvps[index];
//                   final rsvpUrl = 'https://weddingp-9ffea.web.app/rsvp/${rsvp.id}';
                  
//                   return _buildGuestCard(rsvp, rsvpUrl);
//                 },
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
  
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.people_outline,
//             size: 80,
//             color: Colors.pink[100],
//           ),
//           SizedBox(height: 24),
//           Text(
//             "No Guests Added Yet",
//             style: GoogleFonts.lato(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.pink[400],
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             "Add your first guest using the + button",
//             style: GoogleFonts.lato(
//               fontSize: 16,
//               color: Colors.grey[600],
//             ),
//           ),
//           SizedBox(height: 32),
//           ElevatedButton.icon(
//             icon: Icon(Icons.add),
//             label: Text("Add Guest"),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.pink[400],
//               foregroundColor: Colors.white,
//               padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(30),
//               ),
//             ),
//             onPressed: () {
//               showDialog(
//                 context: context,
//                 builder: (context) => AddGuestDialog(
//                   onGuestAdded: () {
//                     _loadStats();
//                   },
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildGuestCard(DocumentSnapshot rsvp, String rsvpUrl) {
//     final data = rsvp.data() as Map<String, dynamic>;
//     final guestName = data['guestName'] ?? 'Guest';
//     final response = data['response'];
//     final email = data['email'] ?? 'Not provided';
    
//     Color statusColor;
//     String statusText;
//     IconData statusIcon;
    
//     if (response == 'Yes') {
//       statusColor = Colors.green[600]!;
//       statusText = 'Attending';
//       statusIcon = Icons.check_circle;
//     } else if (response == 'No') {
//       statusColor = Colors.red[600]!;
//       statusText = 'Not Attending';
//       statusIcon = Icons.cancel;
//     } else {
//       statusColor = Colors.orange[600]!;
//       statusText = 'Pending Response';
//       statusIcon = Icons.access_time;
//     }
    
//     // Format timestamp if available
//     String timestampText = '';
//     if (data['respondedAt'] != null) {
//       final timestamp = data['respondedAt'] as Timestamp;
//       final date = timestamp.toDate();
//       timestampText = 'Responded on ${DateFormat.yMMMd().format(date)}';
//     }
    
//     return Card(
//       margin: EdgeInsets.only(bottom: 16),
//       elevation: 2,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//         side: BorderSide(
//           color: Colors.pink[100]!,
//           width: 1,
//         ),
//       ),
//       child: Column(
//         children: [
//           ListTile(
//             contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//             title: Text(
//               guestName,
//               style: GoogleFonts.lato(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.pink[800],
//               ),
//             ),
//             subtitle: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(height: 4),
//                 Text(
//                   email,
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//                 SizedBox(height: 8),
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: statusColor.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: statusColor.withOpacity(0.3)),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(statusIcon, size: 16, color: statusColor),
//                       SizedBox(width: 4),
//                       Text(
//                         statusText,
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                           color: statusColor,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 if (timestampText.isNotEmpty)
//                   Padding(
//                     padding: EdgeInsets.only(top: 4),
//                     child: Text(
//                       timestampText,
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey[500],
//                         fontStyle: FontStyle.italic,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//             trailing: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.copy, color: Colors.pink[300]),
//                   tooltip: 'Copy RSVP Link',
//                   onPressed: () => _copyToClipboard(context, rsvpUrl),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.qr_code, color: Colors.pink[300]),
//                   tooltip: 'Show QR Code',
//                   onPressed: () {
//                     showDialog(
//                       context: context,
//                       builder: (context) => _buildQRDialog(guestName, rsvpUrl),
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildQRDialog(String guestName, String rsvpUrl) {
//     return Dialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//       ),
//       elevation: 8,
//       child: Container(
//         padding: EdgeInsets.all(24),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(20),
//           color: Colors.white,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.pink.withOpacity(0.1),
//               blurRadius: 20,
//               spreadRadius: 5,
//             ),
//           ],
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               "RSVP QR Code",
//               style: GoogleFonts.dancingScript(
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.pink[700],
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               "For $guestName",
//               style: GoogleFonts.lato(
//                 fontSize: 16,
//                 color: Colors.grey[600],
//               ),
//             ),
//             SizedBox(height: 24),
//             Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.pink[100]!),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.pink.withOpacity(0.1),
//                     blurRadius: 8,
//                     spreadRadius: 2,
//                   ),
//                 ],
//               ),
//               padding: EdgeInsets.all(12),
//               child: QRCodeGenerator(url: rsvpUrl),
//             ),
//             SizedBox(height: 16),
//             Container(
//               padding: EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.grey[50],
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.grey[200]!),
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: SelectableText(
//                       rsvpUrl,
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.grey[700],
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.copy, size: 18, color: Colors.pink[400]),
//                     onPressed: () => _copyToClipboard(context, rsvpUrl),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 24),
//             SizedBox(
//               width: double.infinity,
//               child: TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 style: TextButton.styleFrom(
//                   backgroundColor: Colors.pink[50],
//                   foregroundColor: Colors.pink[700],
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   padding: EdgeInsets.symmetric(vertical: 12),
//                 ),
//                 child: Text("Close", style: TextStyle(fontSize: 16)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class AddGuestDialog extends StatefulWidget {
//   final Function? onGuestAdded;

//   AddGuestDialog({this.onGuestAdded});

//   @override
//   _AddGuestDialogState createState() => _AddGuestDialogState();
// }

// class _AddGuestDialogState extends State<AddGuestDialog> {
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   bool _isAdding = false;

//   Future<void> _addGuest() async {
//     if (_nameController.text.isEmpty) return;
    
//     setState(() {
//       _isAdding = true;
//     });
    
//     try {
//       await FirebaseFirestore.instance.collection('rsvps').add({
//         'guestName': _nameController.text,
//         'email': _emailController.text,
//         'response': null,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
      
//       Navigator.pop(context);
      
//       if (widget.onGuestAdded != null) {
//         widget.onGuestAdded!();
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error adding guest: $e')),
//       );
//     } finally {
//       setState(() {
//         _isAdding = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//       ),
//       elevation: 8,
//       child: Container(
//         padding: EdgeInsets.all(24),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(20),
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               Colors.white,
//               Color(0xFFFCE4EC), // Very light pink
//             ],
//           ),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               "Add New Guest",
//               style: GoogleFonts.dancingScript(
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.pink[700],
//               ),
//             ),
//             SizedBox(height: 20),
//             TextField(
//               controller: _nameController,
//               decoration: InputDecoration(
//                 labelText: 'Guest Name',
//                 labelStyle: TextStyle(color: Colors.pink[300]),
//                 prefixIcon: Icon(Icons.person, color: Colors.pink[300]),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.pink[100]!),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.pink[200]!),
//                 ),
//                 filled: true,
//                 fillColor: Colors.white,
//               ),
//               style: GoogleFonts.lato(),
//             ),
//             SizedBox(height: 16),
//             TextField(
//               controller: _emailController,
//               decoration: InputDecoration(
//                 labelText: 'Email (optional)',
//                 labelStyle: TextStyle(color: Colors.pink[300]),
//                 prefixIcon: Icon(Icons.email, color: Colors.pink[300]),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.pink[100]!),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.pink[200]!),
//                 ),
//                 filled: true,
//                 fillColor: Colors.white,
//               ),
//               keyboardType: TextInputType.emailAddress,
//               style: GoogleFonts.lato(),
//             ),
//             SizedBox(height: 24),
//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton(
//                     onPressed: () => Navigator.pop(context),
//                     style: OutlinedButton.styleFrom(
//                       foregroundColor: Colors.pink[700],
//                       side: BorderSide(color: Colors.pink[200]!),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: Text("Cancel", style: TextStyle(fontSize: 16)),
//                   ),
//                 ),
//                 SizedBox(width: 16),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: _isAdding ? null : _addGuest,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.pink[400],
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                     ),
//                     child: _isAdding
//                         ? SizedBox(
//                             height: 20,
//                             width: 20,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                             ),
//                           )
//                         : Text("Add Guest", style: TextStyle(fontSize: 16)),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

