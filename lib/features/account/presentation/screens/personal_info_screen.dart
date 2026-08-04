import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../auth/data/auth_session_store.dart';
import '../../data/api_profile_repository.dart';
import '../../models/user_profile.dart';

/// Màn "Thông tin cá nhân" cho mobile — hoạt động giống trang Profile web:
/// hiển thị/cập nhật họ tên, giới tính, SĐT, địa chỉ và ảnh đại diện.
///
/// Khác biệt so với web: chạm vào avatar sẽ xin quyền ảnh, mở thư viện ảnh của
/// điện thoại, tải ảnh đã chọn lên Cloudinary rồi TỰ ĐỘNG chọn luôn (không phải
/// bước "chọn ảnh này" lần hai như web).
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({this.repository, super.key});

  final ApiProfileRepository? repository;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late final ApiProfileRepository _repository;
  final _picker = ImagePicker();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  late final Future<UserProfile> _profileFuture;

  int? _gender;
  int? _avatarId;
  String? _avatarUrl; // ảnh hiện tại từ server
  File? _localAvatar; // ảnh vừa chọn (xem trước ngay)

  bool _loaded = false;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ApiProfileRepository();
    _profileFuture = _repository.getMyProfile();
  }

  void _hydrate(UserProfile profile) {
    if (_loaded) return;
    _loaded = true;
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _phoneController.text = profile.phoneNumber ?? '';
    _addressController.text = profile.addresDetail ?? '';
    _gender = profile.gender;
    _avatarId = profile.avatarId;
    _avatarUrl = profile.avatarUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Xin quyền truy cập thư viện ảnh của điện thoại.
  Future<bool> _ensurePhotoPermission() async {
    // Android 13+ và iOS: quyền photos. Android cũ: quyền storage.
    var status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    final storage = await Permission.storage.request();
    if (storage.isGranted) return true;

    if (mounted && (status.isPermanentlyDenied || storage.isPermanentlyDenied)) {
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cần quyền truy cập ảnh'),
          content: const Text(
            'Hãy cấp quyền truy cập ảnh trong Cài đặt để chọn ảnh đại diện.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Mở Cài đặt'),
            ),
          ],
        ),
      );
      if (open == true) await openAppSettings();
    }
    return false;
  }

  /// Chọn ảnh từ thư viện → tải lên Cloudinary → tự động đặt làm avatar.
  Future<void> _pickAndUploadAvatar() async {
    if (_uploading || _saving) return;

    final granted = await _ensurePhotoPermission();
    if (!granted) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final id = await _repository.uploadAvatar(
        fileBytes: bytes,
        fileName: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _avatarId = id; // tự động chọn ảnh vừa tải lên
        _localAvatar = File(picked.path);
      });
      _showSnack('Đã chọn ảnh. Nhấn "Lưu thay đổi" để cập nhật.');
    } catch (error) {
      if (mounted) _showSnack('Tải ảnh lên thất bại: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      _showSnack('Vui lòng nhập họ và tên đầy đủ.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.updateMyProfile(
        firstName: firstName,
        lastName: lastName,
        gender: _gender,
        phoneNumber:
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        addresDetail: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        avatarId: _avatarId,
      );

      // Tải lại hồ sơ để lấy URL avatar mới rồi đồng bộ vào phiên đăng nhập
      // (để header tab "Tôi" hiển thị đúng ảnh + tên).
      final refreshed = await _repository.getMyProfile();
      final session = AuthSessionStore.current;
      if (session != null) {
        await AuthSessionStore.save(
          session.copyWith(
            user: session.user.copyWith(
              fullName: refreshed.fullName,
              avatarUrl: refreshed.avatarUrl,
            ),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _avatarUrl = refreshed.avatarUrl;
        _localAvatar = null;
      });
      _showSnack('Cập nhật hồ sơ thành công.');
    } catch (error) {
      if (mounted) _showSnack('Cập nhật thất bại: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Thông tin cá nhân',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: FutureBuilder<UserProfile>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('Không tải được hồ sơ'));
            }
            _hydrate(snapshot.data!);
            return _buildForm(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildForm(UserProfile profile) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildAvatar(profile)),
          const SizedBox(height: 6),
          Center(
            child: Text(
              profile.email,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _label('Họ'),
          _textField(_firstNameController, hint: 'Nhập họ'),
          const SizedBox(height: 14),
          _label('Tên'),
          _textField(_lastNameController, hint: 'Nhập tên'),
          const SizedBox(height: 14),
          _label('Giới tính'),
          _buildGenderSelector(),
          const SizedBox(height: 14),
          _label('Số điện thoại'),
          _textField(
            _phoneController,
            hint: 'Nhập số điện thoại',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _label('Địa chỉ'),
          _textField(_addressController, hint: 'Nhập địa chỉ', maxLines: 2),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF159447),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Lưu thay đổi',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserProfile profile) {
    final initial = (profile.firstName.isNotEmpty
            ? profile.firstName
            : (profile.username.isNotEmpty ? profile.username : 'U'))
        .characters
        .first
        .toUpperCase();

    ImageProvider? image;
    if (_localAvatar != null) {
      image = FileImage(_localAvatar!);
    } else if ((_avatarUrl ?? '').isNotEmpty) {
      image = NetworkImage(_avatarUrl!);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: const Color(0xFF159447),
          backgroundImage: image,
          child: image == null
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _uploading ? null : _pickAndUploadAvatar,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF159447)),
                        ),
                      )
                    : const Icon(
                        Icons.photo_camera,
                        size: 18,
                        color: Color(0xFF159447),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        _genderChip('Nam', 1),
        const SizedBox(width: 10),
        _genderChip('Nữ', 0),
      ],
    );
  }

  Widget _genderChip(String label, int value) {
    final selected = _gender == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _gender = value),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDCFCE7) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF159447) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF159447) : const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );

  Widget _textField(
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: !_saving,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF159447)),
        ),
      ),
    );
  }
}
