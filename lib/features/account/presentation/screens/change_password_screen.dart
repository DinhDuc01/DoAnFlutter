import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../data/account_repository.dart';
import '../../data/api_account_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({this.repository, super.key});

  final AccountRepository? repository;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final AccountRepository _repository;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiAccountRepository();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (_isSaving) return;

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;
    final error = switch ((currentPassword, newPassword, confirmation)) {
      ('', _, _) => 'Vui lòng nhập mật khẩu hiện tại.',
      (_, String value, _) when value.length < 10 =>
        'Mật khẩu mới phải có ít nhất 10 ký tự.',
      (String current, String next, _) when current == next =>
        'Mật khẩu mới phải khác mật khẩu hiện tại.',
      (_, String next, String confirmed) when next != confirmed =>
        'Mật khẩu nhập lại không khớp.',
      _ => null,
    };

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    var saved = false;
    try {
      await _repository.changePassword(
        oldPassword: currentPassword,
        newPassword: newPassword,
        confirmNewPassword: confirmation,
      );
      saved = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Không thể đổi mật khẩu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && !saved) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4FBF7), // Nền xanh nhạt đồng bộ toàn ứng dụng
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Đổi mật khẩu',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _buildDataState(),
      ),
    );
  }

  Widget _buildDataState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner thông báo màu xanh nhạt
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7), // Nền xanh nhạt mềm mại
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Text(
              'Mật khẩu mới phải khác mật khẩu hiện tại, tối thiểu 10 ký tự.',
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Trường mật khẩu hiện tại
          _buildPasswordField(
            controller: _currentPasswordController,
            hintText: 'Mật khẩu hiện tại',
          ),
          const SizedBox(height: 12),

          // Trường mật khẩu mới
          _buildPasswordField(
            controller: _newPasswordController,
            hintText: 'Mật khẩu mới (tối thiểu 10 ký tự)',
          ),
          const SizedBox(height: 12),

          // Trường nhập lại mật khẩu mới
          _buildPasswordField(
            controller: _confirmPasswordController,
            hintText: 'Nhập lại mật khẩu mới',
          ),
          const SizedBox(height: 80),

          // Nút cập nhật mật khẩu màu xanh lục bo góc tròn pill
          FilledButton(
            onPressed: _isSaving ? null : _savePassword,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Cập nhật mật khẩu',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
