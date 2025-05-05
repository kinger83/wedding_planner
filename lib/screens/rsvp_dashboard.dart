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

class _RSVPDashboardState extends State<RSVPDashboard> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isMounted = false;
  int _attending = 0;
  int _notAttending = 0;
  int _pending = 0;
  
  // Lists for organizing data
  List<Map<String, dynamic>> _attendingGuests = [];
  List<Map<String, dynamic>> _pendingGuests = [];
  List<Map<String, dynamic>> _notAttendingGuests = [];
  List<Map<String, dynamic>> _glutenFreeGuests = [];
  List<Map<String, dynamic>> _songRequests = [];
  List<Map<String, dynamic>> _guestNotes = [];
  
  // For the tab controller
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _tabController = TabController(length: 6, vsync: this);
    _loadGuestData();
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

  Future<void> _loadGuestData() async {
    print('------------ LOAD GUEST DATA START ------------');
    
    try {
      final snapshot = await _firestore.collection('rsvps').get();
      
      if (!_isMounted || !mounted) {
        print('Widget unmounted during data load');
        return;
      }
      
      // Reset counters and lists
      int attending = 0;
      int notAttending = 0;
      int pending = 0;
      List<Map<String, dynamic>> attendingGuests = [];
      List<Map<String, dynamic>> pendingGuests = [];
      List<Map<String, dynamic>> notAttendingGuests = [];
      List<Map<String, dynamic>> glutenFreeGuests = [];
      List<Map<String, dynamic>> songRequests = [];
      List<Map<String, dynamic>> guestNotes = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Add document ID to the data map for reference
        final guestData = {
          'id': doc.id,
          ...data,
        };
        
        final response = data['response'] as String?;
        
        // Categorize by response status
        if (response == 'Yes') {
          attending++;
          attendingGuests.add(guestData);
          
          // Check for dietary restrictions
          if (data['isGlutenIntolerant'] == true) {
            glutenFreeGuests.add(guestData);
          }
          
          // Check for song requests
          if (data['songRequest'] != null && data['songRequest'].toString().isNotEmpty) {
            songRequests.add(guestData);
          }
          
          // Check for notes
          if (data['notes'] != null && data['notes'].toString().isNotEmpty) {
            guestNotes.add(guestData);
          }
        } else if (response == 'No') {
          notAttending++;
          notAttendingGuests.add(guestData);
          
          // Also capture notes from declining guests
          if (data['notes'] != null && data['notes'].toString().isNotEmpty) {
            guestNotes.add(guestData);
          }
        } else {
          // Handle both 'Pending' string and null values
          pending++;
          pendingGuests.add(guestData);
        }
      }

      if (!_isMounted || !mounted) {
        print('Widget unmounted after processing guest data');
        return;
      }
      
      setStateIfMounted(() {
        _attending = attending;
        _notAttending = notAttending;
        _pending = pending;
        _attendingGuests = attendingGuests;
        _pendingGuests = pendingGuests;
        _notAttendingGuests = notAttendingGuests;
        _glutenFreeGuests = glutenFreeGuests;
        _songRequests = songRequests;
        _guestNotes = guestNotes;
        _isLoading = false;
      });
      
      print('Guest data loaded: Yes=$attending, No=$notAttending, Pending=$pending');
      print('------------ LOAD GUEST DATA END ------------');
    } catch (e) {
      print('Error loading guest data: $e');
      if (_isMounted && mounted) {
        setStateIfMounted(() {
          _isLoading = false;
        });
      }
    }
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
            _loadGuestData();
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
                        _buildAllGuestsTab(),
                        _buildAttendingTab(),
                        _buildPendingTab(),
                        _buildGlutenFreeTab(),
                        _buildSongRequestsTab(),
                        _buildNotesTab(),
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
            onPressed: _loadGuestData,
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
                Icon(Icons.people),
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
                Text("Gluten Free"),
              ],
            ),
          ),
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note),
                SizedBox(width: 8),
                Text("Song Requests"),
              ],
            ),
          ),
          Tab(
            icon: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.comment),
                SizedBox(width: 8),
                Text("Notes"),
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
              "Loading your guest list...",
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
  Widget _buildAllGuestsTab() {
    final allGuests = [..._attendingGuests, ..._notAttendingGuests, ..._pendingGuests];
    
    return _buildGuestList(
      title: "All Guests",
      guests: allGuests,
      emptyMessage: "No guests added yet",
      icon: Icons.people_outline,
    );
  }

  Widget _buildAttendingTab() {
    return _buildGuestList(
      title: "Confirmed Attending",
      guests: _attendingGuests,
      emptyMessage: "No guests have confirmed attendance yet",
      icon: Icons.event_available_outlined,
    );
  }

  Widget _buildPendingTab() {
    return _buildGuestList(
      title: "Awaiting Response",
      guests: _pendingGuests,
      emptyMessage: "No pending responses",
      icon: Icons.hourglass_empty_outlined,
    );
  }

  Widget _buildGlutenFreeTab() {
    return _buildGuestList(
      title: "Gluten-Free Requirements",
      guests: _glutenFreeGuests,
      emptyMessage: "No guests have requested gluten-free options",
      icon: Icons.restaurant_outlined,
      showDietaryBadge: true,
    );
  }

  Widget _buildSongRequestsTab() {
    return _buildGuestList(
      title: "Song Requests",
      guests: _songRequests,
      emptyMessage: "No song requests yet",
      icon: Icons.music_note_outlined,
      highlightField: 'songRequest',
    );
  }

  Widget _buildNotesTab() {
    return _buildGuestList(
      title: "Guest Notes",
      guests: _guestNotes,
      emptyMessage: "No notes from guests yet",
      icon: Icons.comment_outlined,
      highlightField: 'notes',
    );
  }
  
  // Unified guest list builder with configuration options
  Widget _buildGuestList({
    required String title,
    required List<Map<String, dynamic>> guests,
    required String emptyMessage,
    required IconData icon,
    bool showDietaryBadge = false,
    String? highlightField,
  }) {
    if (guests.isEmpty) {
      return _buildEmptyState(message: emptyMessage, icon: icon);
    }
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            title,
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
            itemCount: guests.length,
            itemBuilder: (context, index) {
              final guest = guests[index];
              final rsvpUrl = 'https://weddingp-9ffea.web.app/rsvp/${guest['id']}';
              
              return _buildEnhancedGuestCard(
                guest: guest, 
                rsvpUrl: rsvpUrl,
                showDietaryBadge: showDietaryBadge,
                highlightField: highlightField,
              );
            },
          ),
        ),
      ],
    );
  }
  
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
          if (message.contains("No guests")) 
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
              onPressed: _showAddGuestDialog,
            ),
        ],
      ),
    );
  }
  
  // Helper method to build detail rows in the expanded guest card
  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor, 
    required String label, 
    required String value
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
  
  Widget _buildEnhancedGuestCard({
    required Map<String, dynamic> guest, 
    required String rsvpUrl,
    bool showDietaryBadge = false,
    String? highlightField,
  }) {
    final guestName = guest['guestName'] ?? 'Guest';
    final response = guest['response'];
    final email = guest['email'] ?? 'Not provided';
    final notes = guest['notes'] ?? '';
    final songRequest = guest['songRequest'] ?? '';
    final isGlutenIntolerant = guest['isGlutenIntolerant'] == true;
    
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
    } else { // Handles both 'Pending' and null
      statusColor = Colors.orange[600]!;
      statusText = 'Pending Response';
      statusIcon = Icons.access_time;
    }
    
    // Format timestamp if available
    String timestampText = '';
    if (guest['respondedAt'] != null) {
      final timestamp = guest['respondedAt'] as Timestamp;
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
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
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
            Row(
              children: [
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
                
                // Show dietary badge if requested
                if (showDietaryBadge && isGlutenIntolerant)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_outlined, size: 16, color: Colors.amber[800]),
                          SizedBox(width: 4),
                          Text(
                            "Gluten-Free",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.amber[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            // Highlight specific field if requested
            if (highlightField != null && highlightField == 'songRequest' && songRequest.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.music_note, size: 16, color: Colors.purple[400]),
                        SizedBox(width: 6),
                        Text(
                          "Song Request:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      songRequest,
                      style: TextStyle(
                        color: Colors.purple[900],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
            if (highlightField != null && highlightField == 'notes' && notes.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.blue[400]),
                        SizedBox(width: 6),
                        Text(
                          "Notes:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      notes,
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 14,
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
                  builder: (context) => _buildQRDialog(guestName, rsvpUrl),
                );
              },
            ),
          ],
        ),
        // Expanded content with all details
        children: [
          Divider(color: Colors.green[100]),
          SizedBox(height: 8),
          
          // Only show details if guest has responded
          if (response == 'Yes' || response == 'No') ...[
            Text(
              "Guest Details",
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 12),
            
            // Dietary Requirements
            if (isGlutenIntolerant && response == 'Yes')
              _buildDetailRow(
                icon: Icons.restaurant,
                iconColor: Colors.amber[700]!,
                label: "Dietary Requirements",
                value: "Gluten-free options requested",
              ),
              
            // Song Request
            if (songRequest.isNotEmpty)
              _buildDetailRow(
                icon: Icons.music_note,
                iconColor: Colors.purple[600]!,
                label: "Song Request",
                value: songRequest,
              ),
              
            // Notes
            if (notes.isNotEmpty)
              _buildDetailRow(
                icon: Icons.note,
                iconColor: Colors.blue[600]!,
                label: "Additional Notes",
                value: notes,
              ),
              
            // No details provided
            if (!isGlutenIntolerant && songRequest.isEmpty && notes.isEmpty)
              Text(
                "No additional details provided",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
          ],
          
          // Guest hasn't responded yet
          if (response != 'Yes' && response != 'No')
            Text(
              "Awaiting response from this guest",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.orange[700],
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
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
  }

  @override
  void dispose() {
    _isMounted = false;
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Safe setState alternative
  void setStateIfMounted(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _addGuest() async {
    print('------------ ADD GUEST START ------------');
    if (_nameController.text.isEmpty) {
      print('Guest name is empty, not adding');
      return;
    }
    
    setStateIfMounted(() {
      _isAdding = true;
    });
    
    try {
      // Create a complete guest document with all fields
      final guestData = {
        'guestName': _nameController.text,
        'email': _emailController.text,
        'response': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        // Add default values for fields used in GuestRSVPPage
        'notes': '',
        'songRequest': '',
        'isGlutenIntolerant': false,
      };
      
      print('Adding guest with data:');
      guestData.forEach((key, value) {
        print('  $key: $value');
      });
      
      final docRef = await FirebaseFirestore.instance.collection('rsvps').add(guestData);
      print('Guest added successfully with ID: ${docRef.id}');
      
      if (!_isMounted || !mounted) {
        print('Widget unmounted during guest add operation');
        return;
      }
      
      Navigator.pop(context);
      
      if (widget.onGuestAdded != null) {
        widget.onGuestAdded!();
      }
      
      print('------------ ADD GUEST END ------------');
    } catch (e) {
      print('Error adding guest: $e');
      if (e is Error) {
        print('Stack trace: ${e.stackTrace}');
      }
      
      if (_isMounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding guest: $e')),
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
//   bool _isMounted = false;
//   int _attending = 0;
//   int _notAttending = 0;
//   int _pending = 0;

//   @override
//   void initState() {
//     super.initState();
//     _isMounted = true;
//     _loadStats();
//   }

//   @override
//   void dispose() {
//     _isMounted = false;
//     super.dispose();
//   }
  
//   // Safe setState alternative
//   void setStateIfMounted(VoidCallback fn) {
//     if (_isMounted && mounted) {
//       setState(fn);
//     }
//   }

//   Future<void> _loadStats() async {
//     print('------------ LOAD STATS START ------------');
    
//     try {
//       final snapshot = await _firestore.collection('rsvps').get();
      
//       if (!_isMounted || !mounted) {
//         print('Widget unmounted during stats load');
//         return;
//       }
      
//       int attending = 0;
//       int notAttending = 0;
//       int pending = 0;

//       for (var doc in snapshot.docs) {
//         final data = doc.data();
//         final response = data['response'] as String?;
        
//         if (response == 'Yes') {
//           attending++;
//         } else if (response == 'No') {
//           notAttending++;
//         } else if (response == 'Pending' || response == null) {
//           // Handle both 'Pending' string and null values
//           pending++;
//         }
//       }

//       if (!_isMounted || !mounted) {
//         print('Widget unmounted after processing stats data');
//         return;
//       }
      
//       setStateIfMounted(() {
//         _attending = attending;
//         _notAttending = notAttending;
//         _pending = pending;
//         _isLoading = false;
//       });
      
//       print('Stats loaded: Yes=$attending, No=$notAttending, Pending=$pending');
//       print('------------ LOAD STATS END ------------');
//     } catch (e) {
//       print('Error loading stats: $e');
//       if (_isMounted && mounted) {
//         setStateIfMounted(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   void _copyToClipboard(BuildContext context, String text) {
//     if (!_isMounted || !mounted) return;
    
//     Clipboard.setData(ClipboardData(text: text));
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('RSVP link copied to clipboard'),
//         backgroundColor: Colors.green[400],
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//     );
//   }

//   void _signOut() async {
//     try {
//       await _auth.signOut();
//       if (!_isMounted || !mounted) return;
//       Navigator.pushReplacementNamed(context, '/');
//     } catch (e) {
//       print('Error signing out: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               Color(0xFFE8F5E9), // Very light green
//               Color(0xFFC8E6C9), // Light green
//               Color(0xFFF5F5F5), // Almost white
//             ],
//             stops: [0.0, 0.5, 1.0],
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
//           if (!_isMounted || !mounted) return;
          
//           showDialog(
//             context: context,
//             builder: (context) => AddGuestDialog(
//               onGuestAdded: () {
//                 if (_isMounted && mounted) {
//                   _loadStats();
//                 }
//               },
//             ),
//           );
//         },
//         backgroundColor: Colors.green[400],
//         child: Icon(Icons.add, color: Colors.white),
//         elevation: 4,
//       ),
//     );
//   }

//   Widget _buildAppBar() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.9),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.green.withOpacity(0.1),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(20),
//           bottomRight: Radius.circular(20),
//         ),
//         border: Border.all(color: Colors.green[100]!, width: 1),
//       ),
//       child: Row(
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.favorite,
//                     size: 24,
//                     color: Colors.green[400],
//                   ),
//                   SizedBox(width: 8),
//                   Text(
//                     "Wedding RSVP",
//                     style: GoogleFonts.dancingScript(
//                       fontSize: 28,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.green[700],
//                     ),
//                   ),
//                   SizedBox(width: 8),
//                   Icon(
//                     Icons.favorite,
//                     size: 24,
//                     color: Colors.green[400],
//                   ),
//                 ],
//               ),
//               Text(
//                 "Dashboard",
//                 style: GoogleFonts.lato(
//                   fontSize: 14,
//                   color: Colors.green[400],
//                   letterSpacing: 2,
//                 ),
//               ),
//             ],
//           ),
//           Spacer(),
//           _buildStatsCard(),
//           SizedBox(width: 16),
//           IconButton(
//             icon: Icon(Icons.logout, color: Colors.green[400]),
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
//         color: Colors.green[50],
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: Colors.green[100]!),
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
//           Container(width: 1, height: 30, color: Colors.green[100]),
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
//           Container(width: 1, height: 30, color: Colors.green[100]),
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
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
//           ),
//           SizedBox(height: 16),
//           Text(
//             "Loading your guest list...",
//             style: GoogleFonts.lato(
//               color: Colors.green[400],
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
//               color: Colors.green[800],
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
//             color: Colors.green[100],
//           ),
//           SizedBox(height: 24),
//           Text(
//             "No Guests Added Yet",
//             style: GoogleFonts.lato(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.green[400],
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             "Add your first guest using the + button",
//             style: GoogleFonts.lato(
//               fontSize: 16,
//               color: Colors.green[600],
//             ),
//           ),
//           SizedBox(height: 32),
//           ElevatedButton.icon(
//             icon: Icon(Icons.add),
//             label: Text("Add Guest"),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green[400],
//               foregroundColor: Colors.white,
//               padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(30),
//               ),
//               elevation: 5,
//               shadowColor: Colors.green.withOpacity(0.5),
//             ),
//             onPressed: () {
//               if (!_isMounted || !mounted) return;
              
//               showDialog(
//                 context: context,
//                 builder: (context) => AddGuestDialog(
//                   onGuestAdded: () {
//                     if (_isMounted && mounted) {
//                       _loadStats();
//                     }
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
//     } else { // Handles both 'Pending' and null
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
//           color: Colors.green[100]!,
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
//                 color: Colors.green[800],
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
//                     color: Colors.green[600],
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
//                         color: Colors.green[500],
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
//                   icon: Icon(Icons.copy, color: Colors.green[300]),
//                   tooltip: 'Copy RSVP Link',
//                   onPressed: () => _copyToClipboard(context, rsvpUrl),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.qr_code, color: Colors.green[300]),
//                   tooltip: 'Show QR Code',
//                   onPressed: () {
//                     if (!_isMounted || !mounted) return;
                    
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
//               color: Colors.green.withOpacity(0.1),
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
//                 color: Colors.green[700],
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               "For $guestName",
//               style: GoogleFonts.lato(
//                 fontSize: 16,
//                 color: Colors.green[600],
//               ),
//             ),
//             SizedBox(height: 24),
//             Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.green[100]!),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.green.withOpacity(0.1),
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
//                 color: Colors.green[50],
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.green[200]!),
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: SelectableText(
//                       rsvpUrl,
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.green[700],
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.copy, size: 18, color: Colors.green[400]),
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
//                   backgroundColor: Colors.green[50],
//                   foregroundColor: Colors.green[700],
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
//   bool _isMounted = false;

//   @override
//   void initState() {
//     super.initState();
//     _isMounted = true;
//   }

//   @override
//   void dispose() {
//     _isMounted = false;
//     _nameController.dispose();
//     _emailController.dispose();
//     super.dispose();
//   }

//   // Safe setState alternative
//   void setStateIfMounted(VoidCallback fn) {
//     if (_isMounted && mounted) {
//       setState(fn);
//     }
//   }

//   Future<void> _addGuest() async {
//     print('------------ ADD GUEST START ------------');
//     if (_nameController.text.isEmpty) {
//       print('Guest name is empty, not adding');
//       return;
//     }
    
//     setStateIfMounted(() {
//       _isAdding = true;
//     });
    
//     try {
//       // Create a complete guest document with all fields
//       final guestData = {
//         'guestName': _nameController.text,
//         'email': _emailController.text,
//         'response': 'Pending',
//         'createdAt': FieldValue.serverTimestamp(),
//         // Add default values for fields used in GuestRSVPPage
//         'notes': '',
//         'songRequest': '',
//         'isGlutenIntolerant': false,
//       };
      
//       print('Adding guest with data:');
//       guestData.forEach((key, value) {
//         print('  $key: $value');
//       });
      
//       final docRef = await FirebaseFirestore.instance.collection('rsvps').add(guestData);
//       print('Guest added successfully with ID: ${docRef.id}');
      
//       if (!_isMounted || !mounted) {
//         print('Widget unmounted during guest add operation');
//         return;
//       }
      
//       Navigator.pop(context);
      
//       if (widget.onGuestAdded != null) {
//         widget.onGuestAdded!();
//       }
      
//       print('------------ ADD GUEST END ------------');
//     } catch (e) {
//       print('Error adding guest: $e');
//       if (e is Error) {
//         print('Stack trace: ${e.stackTrace}');
//       }
      
//       if (_isMounted && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error adding guest: $e')),
//         );
//       }
//     } finally {
//       if (_isMounted && mounted) {
//         setStateIfMounted(() {
//           _isAdding = false;
//         });
//       }
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
//               Color(0xFFE8F5E9), // Very light green
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
//                 color: Colors.green[700],
//               ),
//             ),
//             SizedBox(height: 20),
//             TextField(
//               controller: _nameController,
//               decoration: InputDecoration(
//                 labelText: 'Guest Name',
//                 labelStyle: TextStyle(color: Colors.green[300]),
//                 prefixIcon: Icon(Icons.person, color: Colors.green[300]),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                   borderSide: BorderSide(color: Colors.green[100]!),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                   borderSide: BorderSide(color: Colors.green[400]!, width: 2),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                   borderSide: BorderSide(color: Colors.green[200]!),
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
//                 labelStyle: TextStyle(color: Colors.green[300]),
//                 prefixIcon: Icon(Icons.email, color: Colors.green[300]),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                   borderSide: BorderSide(color: Colors.green[100]!),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                   borderSide: BorderSide(color: Colors.green[400]!, width: 2),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(15),
//                   borderSide: BorderSide(color: Colors.green[200]!),
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
//                       foregroundColor: Colors.green[700],
//                       side: BorderSide(color: Colors.green[200]!),
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
//                       backgroundColor: Colors.green[400],
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                       elevation: 5,
//                       shadowColor: Colors.green.withOpacity(0.5),
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