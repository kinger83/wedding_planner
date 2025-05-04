import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  String? _errorMessage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }
  
  Future<void> _checkCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      });
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      Navigator.pushReplacementNamed(context, '/dashboard');
    } on FirebaseAuthException catch (e) {
      String message;
      
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email format';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        default:
          message = 'Authentication failed: ${e.message}';
      }
      
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Login error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Beautiful gradient background with greens
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
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Wedding decoration - top
                    _buildDecorativeDivider(),
                    SizedBox(height: 24),
                    
                    // Logo and Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 30,
                          color: Colors.green[400],
                        ),
                        SizedBox(width: 16),
                        Text(
                          "Our Wedding",
                          style: GoogleFonts.dancingScript(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(
                          Icons.favorite,
                          size: 30,
                          color: Colors.green[400],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      "Together Forever",
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        letterSpacing: 3,
                        color: Colors.green[400],
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: 48),
                    
                    // Login Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.green[100]!,
                          width: 1,
                        ),
                      ),
                      padding: EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Admin Login",
                            style: GoogleFonts.lato(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Sign in to manage your wedding details",
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 32),
                          
                          // Email field with beautiful styling
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.green[300]),
                              hintText: 'Enter your email',
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
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 24),
                          
                          // Password field with show/hide option
                          TextField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: Colors.green[300]),
                              hintText: 'Enter your password',
                              prefixIcon: Icon(Icons.lock, color: Colors.green[300]),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.green[300],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
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
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            obscureText: _obscurePassword,
                            style: TextStyle(fontSize: 16),
                            onSubmitted: (_) => _login(),
                          ),
                          
                          // Error message with better styling
                          if (_errorMessage != null)
                            Container(
                              margin: EdgeInsets.only(top: 16),
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red[100]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Colors.red[700], fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          SizedBox(height: 32),
                          
                          // Beautiful login button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[400],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 5,
                                shadowColor: Colors.green.withOpacity(0.5),
                                padding: EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: GoogleFonts.lato(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, size: 20),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Bottom decorative elements
                    Text(
                      "Made with love for your special day",
                      style: GoogleFonts.lato(
                        color: Colors.green[400],
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 24),
                    _buildDecorativeDivider(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Decorative wedding-themed divider with green colors
  Widget _buildDecorativeDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.green[200]!],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.favorite, size: 20, color: Colors.green[300]),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.catching_pokemon, size: 20, color: Colors.green[300]),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.favorite, size: 20, color: Colors.green[300]),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[200]!, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}



// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_fonts/google_fonts.dart';

// class LoginScreen extends StatefulWidget {
//   LoginScreen({Key? key}) : super(key: key);

//   @override
//   _LoginScreenState createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _auth = FirebaseAuth.instance;
//   String? _errorMessage;
//   bool _isLoading = false;
//   bool _obscurePassword = true;

//   @override
//   void initState() {
//     super.initState();
//     _checkCurrentUser();
//   }
  
//   Future<void> _checkCurrentUser() async {
//     final user = _auth.currentUser;
//     if (user != null) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         Navigator.pushReplacementNamed(context, '/dashboard');
//       });
//     }
//   }

//   Future<void> _login() async {
//     if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
//       setState(() {
//         _errorMessage = 'Please enter both email and password';
//       });
//       return;
//     }
    
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
    
//     try {
//       await _auth.signInWithEmailAndPassword(
//         email: _emailController.text.trim(),
//         password: _passwordController.text.trim(),
//       );
      
//       Navigator.pushReplacementNamed(context, '/dashboard');
//     } on FirebaseAuthException catch (e) {
//       String message;
      
//       switch (e.code) {
//         case 'user-not-found':
//           message = 'No user found with this email';
//           break;
//         case 'wrong-password':
//           message = 'Incorrect password';
//           break;
//         case 'invalid-email':
//           message = 'Invalid email format';
//           break;
//         case 'user-disabled':
//           message = 'This account has been disabled';
//           break;
//         default:
//           message = 'Authentication failed: ${e.message}';
//       }
      
//       setState(() {
//         _errorMessage = message;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Login error: ${e.toString()}';
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           // Beautiful gradient background
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//              Color(0xFFE8F5E9), // Very light green
//             Color(0xFFC8E6C9), // Light green
//             Color(0xFFF5F5F5), // Almost white
//             ],
//             stops: [0.0, 0.5, 1.0],
//           ),
//         ),
//         child: SafeArea(
//           child: Center(
//             child: SingleChildScrollView(
//               child: Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 24),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // Wedding decoration - top
//                     _buildDecorativeDivider(),
//                     SizedBox(height: 24),
                    
//                     // Logo and Title
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.favorite,
//                           size: 30,
//                           color: Colors.pink[400],
//                         ),
//                         SizedBox(width: 16),
//                         Text(
//                           "Kirsty & Jason Wedding",
//                           style: GoogleFonts.dancingScript(
//                             fontSize: 42,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.green[700],
//                           ),
//                         ),
//                         SizedBox(width: 16),
//                         Icon(
//                           Icons.favorite,
//                           size: 30,
//                           color: Colors.pink[400],
//                         ),
//                       ],
//                     ),
//                     SizedBox(height: 8),
                    
//                     // Subtitle
//                     Text(
//                       "Together Forever",
//                       style: GoogleFonts.lato(
//                         fontSize: 16,
//                         letterSpacing: 3,
//                         color: Colors.pink[400],
//                         fontWeight: FontWeight.w300,
//                       ),
//                     ),
//                     SizedBox(height: 48),
                    
//                     // Login Card
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.9),
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.pink.withOpacity(0.1),
//                             blurRadius: 20,
//                             spreadRadius: 5,
//                             offset: Offset(0, 10),
//                           ),
//                         ],
//                         border: Border.all(
//                           color: Colors.pink[100]!,
//                           width: 1,
//                         ),
//                       ),
//                       padding: EdgeInsets.all(32),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Admin Login",
//                             style: GoogleFonts.lato(
//                               fontSize: 24,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.pink[800],
//                             ),
//                           ),
//                           SizedBox(height: 8),
//                           Text(
//                             "Sign in to manage your wedding details",
//                             style: GoogleFonts.lato(
//                               fontSize: 14,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                           SizedBox(height: 32),
                          
//                           // Email field with beautiful styling
//                           TextField(
//                             controller: _emailController,
//                             decoration: InputDecoration(
//                               labelText: 'Email',
//                               labelStyle: TextStyle(color: Colors.pink[300]),
//                               hintText: 'Enter your email',
//                               prefixIcon: Icon(Icons.email, color: Colors.pink[300]),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: BorderSide(color: Colors.pink[100]!),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: BorderSide(color: Colors.pink[200]!),
//                               ),
//                               filled: true,
//                               fillColor: Colors.white,
//                               contentPadding: EdgeInsets.symmetric(vertical: 16),
//                             ),
//                             keyboardType: TextInputType.emailAddress,
//                             style: TextStyle(fontSize: 16),
//                           ),
//                           SizedBox(height: 24),
                          
//                           // Password field with show/hide option
//                           TextField(
//                             controller: _passwordController,
//                             decoration: InputDecoration(
//                               labelText: 'Password',
//                               labelStyle: TextStyle(color: Colors.pink[300]),
//                               hintText: 'Enter your password',
//                               prefixIcon: Icon(Icons.lock, color: Colors.pink[300]),
//                               suffixIcon: IconButton(
//                                 icon: Icon(
//                                   _obscurePassword ? Icons.visibility_off : Icons.visibility,
//                                   color: Colors.pink[300],
//                                 ),
//                                 onPressed: () {
//                                   setState(() {
//                                     _obscurePassword = !_obscurePassword;
//                                   });
//                                 },
//                               ),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: BorderSide(color: Colors.pink[100]!),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: BorderSide(color: Colors.pink[200]!),
//                               ),
//                               filled: true,
//                               fillColor: Colors.white,
//                               contentPadding: EdgeInsets.symmetric(vertical: 16),
//                             ),
//                             obscureText: _obscurePassword,
//                             style: TextStyle(fontSize: 16),
//                             onSubmitted: (_) => _login(),
//                           ),
                          
//                           // Error message with better styling
//                           if (_errorMessage != null)
//                             Container(
//                               margin: EdgeInsets.only(top: 16),
//                               padding: EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: Colors.red[50],
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: Border.all(color: Colors.red[100]!),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Icon(Icons.error_outline, color: Colors.red[400], size: 20),
//                                   SizedBox(width: 10),
//                                   Expanded(
//                                     child: Text(
//                                       _errorMessage!,
//                                       style: TextStyle(color: Colors.red[700], fontSize: 14),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
                          
//                           SizedBox(height: 32),
                          
//                           // Beautiful login button
//                           SizedBox(
//                             width: double.infinity,
//                             height: 56,
//                             child: ElevatedButton(
//                               onPressed: _isLoading ? null : _login,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.pink[400],
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(30),
//                                 ),
//                                 elevation: 5,
//                                 shadowColor: Colors.pink.withOpacity(0.5),
//                                 padding: EdgeInsets.symmetric(vertical: 15),
//                               ),
//                               child: _isLoading
//                                   ? SizedBox(
//                                       height: 24,
//                                       width: 24,
//                                       child: CircularProgressIndicator(
//                                         color: Colors.white,
//                                         strokeWidth: 2,
//                                       ),
//                                     )
//                                   : Row(
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         Text(
//                                           'Sign In',
//                                           style: GoogleFonts.lato(
//                                             fontSize: 18,
//                                             fontWeight: FontWeight.bold,
//                                             letterSpacing: 1.2,
//                                           ),
//                                         ),
//                                         SizedBox(width: 8),
//                                         Icon(Icons.arrow_forward, size: 20),
//                                       ],
//                                     ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                    
//                     SizedBox(height: 40),
                    
//                     // Bottom decorative elements
//                     Text(
//                       "Made with love for your special day",
//                       style: GoogleFonts.lato(
//                         color: Colors.pink[400],
//                         fontStyle: FontStyle.italic,
//                         fontSize: 14,
//                       ),
//                     ),
//                     SizedBox(height: 24),
//                     _buildDecorativeDivider(),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // Decorative wedding-themed divider
//   Widget _buildDecorativeDivider() {
//     return Row(
//       children: [
//         Expanded(
//           child: Container(
//             height: 1,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Colors.transparent, Colors.pink[200]!],
//               ),
//             ),
//           ),
//         ),
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 8),
//           child: Icon(Icons.favorite, size: 20, color: Colors.pink[300]),
//         ),
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 8),
//           child: Icon(Icons.catching_pokemon, size: 20, color: Colors.pink[300]),
//         ),
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 8),
//           child: Icon(Icons.favorite, size: 20, color: Colors.pink[300]),
//         ),
//         Expanded(
//           child: Container(
//             height: 1,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Colors.pink[200]!, Colors.transparent],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
// }
