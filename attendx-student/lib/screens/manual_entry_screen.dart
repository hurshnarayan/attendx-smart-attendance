// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'package:provider/provider.dart';
// import '../providers/app_provider.dart';
// import '../utils/constants.dart';
// import 'result_screen.dart';

// class ManualEntryScreen extends StatefulWidget {
//   const ManualEntryScreen({super.key});

//   @override
//   State<ManualEntryScreen> createState() => _ManualEntryScreenState();
// }

// class _ManualEntryScreenState extends State<ManualEntryScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _tokenController = TextEditingController();
//   final _pinController = TextEditingController();
//   final _classIdController = TextEditingController(text: 'CS101');

//   @override
//   void dispose() {
//     _tokenController.dispose();
//     _pinController.dispose();
//     _classIdController.dispose();
//     super.dispose();
//   }

// //   Future<void> _submit() async {
// //     if (!_formKey.currentState!.validate()) return;

// //     HapticFeedback.mediumImpact();

// //     final provider = context.read<AppProvider>();

// //     final result = await provider.markAttendance(
// //       token: _tokenController.text.trim(),
// //       pin: _pinController.text.trim(),
// //       classId: _classIdController.text.trim().isNotEmpty
// //           ? _classIdController.text.trim()
// //           : 'DEFAULT',
// //       authMethod: "manual", // I added this cuz i dont it was erroring out, you please fix it if you encounter this claude
// // );

// //     );

// //     if (mounted) {
// //       Navigator.pushReplacement(
// //         context,
// //         MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
// //       );
// //     }
// //   }
//   Future<void> _submit() async {
//   if (!_formKey.currentState!.validate()) return;

//   HapticFeedback.mediumImpact();

//   final provider = context.read<AppProvider>();

//   final result = await provider.markAttendance(
//     token: _tokenController.text.trim(),
//     pin: _pinController.text.trim(),
//     classId: _classIdController.text.trim().isNotEmpty
//         ? _classIdController.text.trim()
//         : 'DEFAULT',
//     authMethod: 'manual',
//   );

//   if (!mounted) return;

//   Navigator.pushReplacement(
//     context,
//     MaterialPageRoute(
//       builder: (_) => ResultScreen(result: result),
//     ),
//   );
// }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: AppColors.gray100,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: const Icon(
//               Icons.arrow_back_rounded,
//               color: AppColors.gray700,
//               size: 22,
//             ),
//           ),
//         ),
//         title: const Text(
//           'Manual Entry',
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//             color: AppColors.gray900,
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Illustration
//               Center(
//                 child: Container(
//                   width: 120,
//                   height: 120,
//                   decoration: BoxDecoration(
//                     color: AppColors.gray100,
//                     borderRadius: BorderRadius.circular(28),
//                   ),
//                   child: const Icon(
//                     Icons.edit_note_rounded,
//                     size: 60,
//                     color: AppColors.gray400,
//                   ),
//                 ),
//               ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),

//               const SizedBox(height: 32),

//               // Title
//               const Center(
//                 child: Text(
//                   'Enter Token Details',
//                   style: TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.w700,
//                     color: AppColors.gray900,
//                   ),
//                 ),
//               ).animate(delay: 100.ms).fadeIn(),

//               const SizedBox(height: 8),

//               Center(
//                 child: Text(
//                   'Copy the token from teacher\'s screen',
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: AppColors.gray500,
//                   ),
//                 ),
//               ).animate(delay: 150.ms).fadeIn(),

//               const SizedBox(height: 40),

//               // Token Field
//               _buildLabel('Token String'),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: _tokenController,
//                 maxLines: 3,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                   fontFamily: 'monospace',
//                   color: AppColors.gray900,
//                 ),
//                 decoration: InputDecoration(
//                   hintText: 'Paste the token here...',
//                   hintStyle: TextStyle(
//                     color: AppColors.gray400,
//                     fontFamily: 'monospace',
//                   ),
//                   filled: true,
//                   fillColor: AppColors.gray50,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.gray200, width: 2),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.gray200, width: 2),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.primary, width: 2),
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.danger, width: 2),
//                   ),
//                   suffixIcon: IconButton(
//                     onPressed: () async {
//                       final data = await Clipboard.getData(Clipboard.kTextPlain);
//                       if (data?.text != null) {
//                         _tokenController.text = data!.text!;
//                         HapticFeedback.lightImpact();
//                       }
//                     },
//                     icon: const Icon(Icons.paste_rounded, color: AppColors.gray400),
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the token';
//                   }
//                   return null;
//                 },
//               ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.05, end: 0),

//               const SizedBox(height: 24),

//               // PIN Field
//               _buildLabel('PIN'),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: _pinController,
//                 keyboardType: TextInputType.number,
//                 maxLength: 4,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.w700,
//                   letterSpacing: 12,
//                   color: AppColors.gray900,
//                 ),
//                 decoration: InputDecoration(
//                   counterText: '',
//                   hintText: '• • • •',
//                   hintStyle: const TextStyle(
//                     fontSize: 24,
//                     color: AppColors.gray300,
//                     letterSpacing: 12,
//                   ),
//                   filled: true,
//                   fillColor: AppColors.gray50,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.gray200, width: 2),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.gray200, width: 2),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.primary, width: 2),
//                   ),
//                   errorBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.danger, width: 2),
//                   ),
//                 ),
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter the PIN';
//                   }
//                   if (value.length != 4) {
//                     return 'PIN must be 4 digits';
//                   }
//                   return null;
//                 },
//               ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.05, end: 0),

//               const SizedBox(height: 24),

//               // Class ID Field
//               _buildLabel('Class ID (Optional)'),
//               const SizedBox(height: 8),
//               TextFormField(
//                 controller: _classIdController,
//                 textCapitalization: TextCapitalization.characters,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: AppColors.gray900,
//                 ),
//                 decoration: InputDecoration(
//                   hintText: 'e.g., CS101',
//                   filled: true,
//                   fillColor: AppColors.gray50,
//                   prefixIcon: const Icon(Icons.class_rounded, color: AppColors.gray400),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.gray200, width: 2),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.gray200, width: 2),
//                   ),
//                   focusedBorder: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(14),
//                     borderSide: const BorderSide(color: AppColors.primary, width: 2),
//                   ),
//                 ),
//               ).animate(delay: 400.ms).fadeIn().slideX(begin: 0.05, end: 0),

//               const SizedBox(height: 40),

//               // Submit Button
//               Consumer<AppProvider>(
//                 builder: (context, provider, _) {
//                   return SizedBox(
//                     width: double.infinity,
//                     height: 56,
//                     child: ElevatedButton(
//                       onPressed: provider.isLoading ? null : _submit,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: AppColors.primary,
//                         disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                       ),
//                       child: provider.isLoading
//                           ? const SizedBox(
//                               width: 24,
//                               height: 24,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2.5,
//                                 valueColor: AlwaysStoppedAnimation(Colors.white),
//                               ),
//                             )
//                           : const Text(
//                               'Mark Attendance',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                                 color: Colors.white,
//                               ),
//                             ),
//                     ),
//                   );
//                 },
//               ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.1, end: 0),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildLabel(String text) {
//     return Text(
//       text,
//       style: const TextStyle(
//         fontSize: 14,
//         fontWeight: FontWeight.w600,
//         color: AppColors.gray700,
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'result_screen.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _classIdController =
      TextEditingController(text: 'CS101');

  @override
  void dispose() {
    _tokenController.dispose();
    _pinController.dispose();
    _classIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();

    final provider = context.read<AppProvider>();

    final result = await provider.markAttendance(
      token: _tokenController.text.trim(),
      pin: _pinController.text.trim(),
      classId: _classIdController.text.trim().isNotEmpty
          ? _classIdController.text.trim()
          : 'DEFAULT',
      authMethod: 'manual',
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.gray700,
              size: 22,
            ),
          ),
        ),
        title: const Text(
          'Manual Entry',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.gray900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    size: 60,
                    color: AppColors.gray400,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).scale(),

              const SizedBox(height: 32),

              const Center(
                child: Text(
                  'Enter Token Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900,
                  ),
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  "Copy the token from teacher's screen",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.gray500,
                  ),
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 40),

              _buildLabel('Token String'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tokenController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Paste the token here...',
                  filled: true,
                  fillColor: AppColors.gray50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste_rounded),
                    onPressed: () async {
                      final data =
                          await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _tokenController.text = data!.text!;
                      }
                    },
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter token' : null,
              ).animate().fadeIn(),

              const SizedBox(height: 24),

              _buildLabel('PIN'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '• • • •',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter PIN';
                  if (value.length != 4) return 'PIN must be 4 digits';
                  return null;
                },
              ).animate().fadeIn(),

              const SizedBox(height: 24),

              _buildLabel('Class ID (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _classIdController,
                decoration: const InputDecoration(
                  hintText: 'e.g. CS101',
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 40),

              Consumer<AppProvider>(
                builder: (_, provider, __) {
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _submit,
                      child: provider.isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text('Mark Attendance'),
                    ),
                  );
                },
              ).animate().fadeIn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.gray700,
      ),
    );
  }
}
