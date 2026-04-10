import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/admin_pages/admin_main_layout.dart';
import 'package:quality_review/pages/employee_pages/employee_main_layout.dart';
import '../controllers/auth_controller.dart';

// ---------- Controller using GetX ----------
class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  var isLoading = false.obs;

  void login() async {
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar(
        "Error",
        "Please enter both email and password",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;
    try {
      final auth = Get.find<AuthController>();
      final user = await auth.login(email, password);
      final isAdmin = user.role.toLowerCase() == 'admin';

      Get.offAll(() => isAdmin ? AdminMainLayout() : EmployeeMainLayout());

      // Preload projects for employees after navigation (non-blocking)
      if (!isAdmin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          auth.preloadEmployeeProjects();
        });
      }
    } catch (e) {
      Get.snackbar(
        'Login Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
}

// ---------- Login Screen ----------
class LoginPage extends StatefulWidget {
  LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LoginController controller = Get.find<LoginController>();
  bool _obscurePassword = true;

  // Teal color matching the reference image
  static const Color _teal = Color(0xFF2A9D8F);

  /// Builds a labelled text field that matches the reference screenshot:
  ///  • Label text sits ABOVE the box
  ///  • Teal outlined border (thicker when focused)
  ///  • Hint text inside the box
  ///  • Prefix icon in teal
  Widget _buildField({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required TextEditingController textController,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label above the box ──
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 6),
        // ── Text field ──
        TextField(
          controller: textController,
          obscureText: obscure,
          cursorColor: _teal,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
            prefixIcon: Icon(prefixIcon, color: _teal, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _teal, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Container(
            height: 520,
            width: MediaQuery.of(context).size.width / 3.3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 0, 59, 236)
                      .withValues(alpha: 0.3),
                  spreadRadius: 10,
                  blurRadius: 310,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  // ── Title ──
                  const Center(
                    child: Text(
                      "Welcome Back",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 45,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "Sign in to your account to continue",
                      style: TextStyle(color: Color.fromARGB(255, 37, 37, 37)),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Email Field ──
                  _buildField(
                    label: 'Email',
                    hint: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    textController: controller.emailController,
                  ),
                  const SizedBox(height: 20),

                  // ── Password Field ──
                  _buildField(
                    label: 'Password',
                    hint: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
                    textController: controller.passwordController,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Login Button ──
                  Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return GestureDetector(
                      onTap: controller.login,
                      child: Container(
                        height: 48,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
