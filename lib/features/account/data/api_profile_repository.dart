import '../../../core/api/api_client.dart';
import '../../../core/api/json_reader.dart';
import '../../auth/data/auth_session_store.dart';
import '../models/user_profile.dart';

/// Repository cho hồ sơ cá nhân + upload ảnh đại diện (giống trang Profile web).
class ApiProfileRepository {
  ApiProfileRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  String get _token {
    final token = AuthSessionStore.current?.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        message: 'Bạn cần đăng nhập để thực hiện thao tác này.',
      );
    }
    return token;
  }

  /// Lấy hồ sơ của chính người dùng đang đăng nhập.
  Future<UserProfile> getMyProfile() async {
    final json = await _apiClient.get('/api/v1/user/me', token: _token);
    final data = JsonReader.map(json, 'resources');
    if (data == null) {
      throw const ApiException(message: 'Không tải được hồ sơ.');
    }
    final avatar = JsonReader.map(data, 'avatar');
    return UserProfile(
      id: JsonReader.integer(data, 'id') ?? 0,
      username: JsonReader.string(data, 'username') ?? '',
      firstName: JsonReader.string(data, 'firstName') ?? '',
      lastName: JsonReader.string(data, 'lastName') ?? '',
      email: JsonReader.string(data, 'email') ?? '',
      gender: JsonReader.integer(data, 'gender'),
      phoneNumber: JsonReader.string(data, 'phoneNumber'),
      addresDetail: JsonReader.string(data, 'addresDetail'),
      avatarId: avatar == null ? null : JsonReader.integer(avatar, 'id'),
      avatarUrl: avatar == null ? null : JsonReader.string(avatar, 'url'),
    );
  }

  /// Cập nhật hồ sơ cá nhân (PUT /user/me). [avatarId] có thể null để gỡ ảnh.
  Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    int? gender,
    String? phoneNumber,
    String? addresDetail,
    int? avatarId,
  }) async {
    final json = await _apiClient.put(
      '/api/v1/user/me',
      token: _token,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender,
        'phoneNumber': phoneNumber,
        // Trường CCCD/CMND không dùng ở mobile → gửi null.
        'identityNumber': null,
        'addresDetail': addresDetail,
        'avatarId': avatarId,
      },
    );
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw ApiException(
        message: JsonReader.string(json, 'message') ?? 'Cập nhật hồ sơ thất bại.',
      );
    }
  }

  /// Tải ảnh lên Cloudinary qua File Manager và trả về id ảnh vừa tạo.
  ///
  /// Backend yêu cầu ảnh nằm trong một thư mục → tự lấy/khởi tạo một thư mục
  /// (mobile không cần cho người dùng chọn thư mục như web).
  Future<int> uploadAvatar({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final folderId = await _ensureFolderId();
    final json = await _apiClient.postMultipart(
      '/api/v1/file-manager/upload',
      token: _token,
      fileField: 'Files',
      fileName: fileName,
      fileBytes: fileBytes,
      fields: {'FolderUploadId': folderId.toString()},
    );
    if (JsonReader.boolean(json, 'isSucceeded') == false) {
      throw ApiException(
        message: JsonReader.string(json, 'message') ?? 'Tải ảnh lên thất bại.',
      );
    }
    final resources = JsonReader.map(json, 'resources');
    final id = resources == null ? null : JsonReader.integer(resources, 'id');
    if (id == null) {
      throw const ApiException(message: 'Không lấy được ảnh sau khi tải lên.');
    }
    return id;
  }

  /// Lấy id một thư mục để chứa ảnh; nếu chưa có thì tạo thư mục "Avatar".
  Future<int> _ensureFolderId() async {
    final json =
        await _apiClient.get('/api/v1/file-manager/folders', token: _token);
    final folders = JsonReader.list(json, 'resources') ?? const [];
    if (folders.isNotEmpty && folders.first is Map<String, dynamic>) {
      final id =
          JsonReader.integer(folders.first as Map<String, dynamic>, 'id');
      if (id != null) return id;
    }
    // Chưa có thư mục nào → tạo mới.
    final created = await _apiClient.post(
      '/api/v1/file-manager/folders',
      token: _token,
      body: {'folderName': 'Avatar', 'parentId': 0},
    );
    final newId = JsonReader.integer(created, 'resources');
    if (newId == null) {
      throw const ApiException(message: 'Không tạo được thư mục lưu ảnh.');
    }
    return newId;
  }
}
