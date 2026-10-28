import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fresh_keep_frontend/shared/presentation/design_system/views/ds_app_bar.dart';
import 'package:fresh_keep_frontend/shared/presentation/design_system/views/ds_elevated_button.dart';
import 'package:fresh_keep_frontend/shared/presentation/design_system/views/ds_text_form_field.dart';
import 'package:go_router/go_router.dart';

import '../bloc/form_status.dart';
import '../bloc/register_bloc.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8 || value.length > 20) {
      return 'Password must be between 8 and 20 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<RegisterBloc>().add(
        RegisterSubmitted(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DSAppBar(title: 'Create account'),
      body: BlocListener<RegisterBloc, FormStatus>(
        listener: (context, state) {
          if (state is FormFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is FormSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created successfully! Please log in to continue.',
                ),
              ),
            );
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) context.go('/login');
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DSTextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  labelText: 'Email',
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                DSTextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  labelText: 'Password',
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                DSTextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  labelText: 'Confirm password',
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 24),
                BlocBuilder<RegisterBloc, FormStatus>(
                  builder: (context, state) {
                    final isSubmitting = state is FormSubmitting;
                    return DSElevatedButton(
                      text: "Register",
                      isSubmitting: isSubmitting,
                      submit: _submit,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Log in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
