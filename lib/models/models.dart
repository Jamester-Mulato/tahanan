class UserModel {
  final String id, email, displayName;
  final String? username;
  final String? avatarUrl;
  final bool isAdmin;
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.isAdmin = false,
  });
  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: j['displayName'] as String,
        username: j['username'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        isAdmin: j['isAdmin'] == true,
      );
}

class BoardingHouse {
  final String id, name, domain, joinKey, role;
  final String ownerName, ownerEmail;
  final String? ownerAvatarUrl;

  const BoardingHouse({
    required this.id,
    required this.name,
    required this.domain,
    required this.joinKey,
    required this.role,
    this.ownerName = '',
    this.ownerEmail = '',
    this.ownerAvatarUrl,
  });

  factory BoardingHouse.fromJson(Map<String, dynamic> j) => BoardingHouse(
        id: (j['boardingHouseId'] ?? j['id']) as String,
        name: (j['name'] ?? '') as String,
        domain: (j['domain'] ?? '') as String,
        joinKey: (j['joinKey'] ?? '') as String,
        role: (j['role'] ?? 'tenant') as String,
        ownerName: (j['ownerName'] ?? '') as String,
        ownerEmail: (j['ownerEmail'] ?? '') as String,
        ownerAvatarUrl: j['ownerAvatarUrl'] as String?,
      );
}

class RemovedBoardingHouse {
  final String boardingHouseId, name, domain, joinKey;
  final String ownerName, ownerEmail;
  final DateTime? removedAt;

  const RemovedBoardingHouse({
    required this.boardingHouseId,
    required this.name,
    required this.domain,
    required this.joinKey,
    required this.ownerName,
    required this.ownerEmail,
    this.removedAt,
  });

  factory RemovedBoardingHouse.fromJson(Map<String, dynamic> j) =>
      RemovedBoardingHouse(
        boardingHouseId: (j['boardingHouseId'] ?? j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        domain: (j['domain'] ?? '') as String,
        joinKey: (j['joinKey'] ?? '') as String,
        ownerName: (j['ownerName'] ?? '') as String,
        ownerEmail: (j['ownerEmail'] ?? '') as String,
        removedAt: j['removedAt'] == null
            ? null
            : DateTime.tryParse(j['removedAt'].toString()),
      );
}

class DashboardData {
  final String name, domain, joinKey;
  final int rooms, tenants, openSlots, concerns, unassigned;
  const DashboardData({
    required this.name,
    required this.domain,
    required this.joinKey,
    required this.rooms,
    required this.tenants,
    required this.openSlots,
    required this.concerns,
    required this.unassigned,
  });
  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        name: (j['name'] ?? '') as String,
        domain: (j['domain'] ?? '') as String,
        joinKey: (j['joinKey'] ?? '') as String,
        rooms: _i(j['totalRooms']),
        tenants: _i(j['totalTenants']),
        openSlots: _i(j['openSlots']),
        concerns: _i(j['activeConcerns']),
        unassigned: _i(j['unassignedAccounts']),
      );
}

class RoomModel {
  final String id, roomNumber, occupancyStatus;
  final int capacity, occupied, available;
  const RoomModel({
    required this.id,
    required this.roomNumber,
    required this.capacity,
    required this.occupied,
    required this.available,
    required this.occupancyStatus,
  });
  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
        id: j['id'] as String,
        roomNumber: (j['roomNumber'] ?? '') as String,
        capacity: _i(j['capacity']),
        occupied: _i(j['occupiedSlots'] ?? j['occupied']),
        available: _i(j['availableSlots'] ?? j['available']),
        occupancyStatus: (j['occupancyStatus'] ?? 'available') as String,
      );

  bool get isFull => occupied >= capacity || occupancyStatus == 'full';
}

class TenantModel {
  final String id, fullName;
  final String? email, accountEmail, roomNumber, roomId, userId, paymentStatus;
  const TenantModel({
    required this.id,
    required this.fullName,
    this.email,
    this.accountEmail,
    this.roomNumber,
    this.roomId,
    this.userId,
    this.paymentStatus,
  });
  factory TenantModel.fromJson(Map<String, dynamic> j) => TenantModel(
        id: j['id'] as String,
        fullName: (j['fullName'] ?? '') as String,
        email: j['email'] as String?,
        accountEmail: j['accountEmail'] as String?,
        roomNumber: j['roomNumber'] as String?,
        roomId: j['roomId'] as String?,
        userId: j['userId'] as String?,
        paymentStatus: (j['paymentStatus'] ?? j['status'] ?? 'paid') as String?,
      );

  String get displayEmail => accountEmail ?? email ?? 'No email';
}

class UnassignedAccount {
  final String userId, email, displayName;
  final String? avatarUrl;
  final DateTime? joinedAt;
  const UnassignedAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.joinedAt,
  });
  factory UnassignedAccount.fromJson(Map<String, dynamic> j) =>
      UnassignedAccount(
        userId: j['userId'] as String,
        email: (j['email'] ?? '') as String,
        displayName: (j['displayName'] ?? '') as String,
        avatarUrl: j['avatarUrl'] as String?,
        joinedAt: j['joinedAt'] == null
            ? null
            : DateTime.tryParse(j['joinedAt'].toString()),
      );
}

class AnnouncementModel {
  final String id, title, message;
  final DateTime? publishedAt;
  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    this.publishedAt,
  });
  factory AnnouncementModel.fromJson(Map<String, dynamic> j) =>
      AnnouncementModel(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        message: (j['message'] ?? '') as String,
        publishedAt: j['publishedAt'] == null
            ? null
            : DateTime.tryParse(j['publishedAt'].toString()),
      );
}

class ConcernAttachmentModel {
  final String id;
  final String? publicUrl, fileName, mimeType;
  final DateTime? createdAt;

  const ConcernAttachmentModel({
    required this.id,
    this.publicUrl,
    this.fileName,
    this.mimeType,
    this.createdAt,
  });

  factory ConcernAttachmentModel.fromJson(Map<String, dynamic> j) =>
      ConcernAttachmentModel(
        id: (j['id'] ?? '') as String,
        publicUrl: j['publicUrl'] as String?,
        fileName: j['fileName'] as String?,
        mimeType: j['mimeType'] as String?,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'].toString()),
      );
}

class ConcernModel {
  final String id, subject, details, category, status;
  final String? tenantName, roomNumber, ownerResponse;
  final List<ConcernAttachmentModel> attachments;
  final DateTime? createdAt;
  final int? rating;

  static const statusUnread = 'unread';
  static const statusPending = 'pending';
  static const statusResolved = 'resolved';

  const ConcernModel({
    required this.id,
    required this.subject,
    required this.details,
    required this.category,
    required this.status,
    this.tenantName,
    this.roomNumber,
    this.ownerResponse,
    this.attachments = const [],
    this.createdAt,
    this.rating,
  });
  factory ConcernModel.fromJson(Map<String, dynamic> j) {
    var rawAtts = j['attachments'];
    List<ConcernAttachmentModel> atts = [];
    if (rawAtts is List) {
      atts = rawAtts
          .map(
              (a) => ConcernAttachmentModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    return ConcernModel(
      id: j['id'] as String,
      subject: (j['subject'] ?? '') as String,
      details: (j['details'] ?? '') as String,
      category: (j['category'] ?? 'maintenance') as String,
      status: _normalizeStatus(j['status']),
      tenantName: j['tenantName'] as String?,
      roomNumber: j['roomNumber'] as String?,
      ownerResponse: j['ownerResponse'] as String?,
      attachments: atts,
      createdAt: j['createdAt'] == null
          ? null
          : DateTime.tryParse(j['createdAt'].toString()),
      rating: j['rating'] as int?,
    );
  }

  static String _normalizeStatus(dynamic s) {
    final status = '$s'.toLowerCase();
    if (status == 'open') return statusUnread;
    if (status == 'in_progress') return statusPending;
    if (status == 'unread' || status == 'pending' || status == 'resolved') {
      return status;
    }
    return statusUnread;
  }
}

class TenantMonthlyStatusModel {
  final String id, tenantId, academicYearId, academicYear, monthStart, status;

  const TenantMonthlyStatusModel({
    required this.id,
    required this.tenantId,
    required this.academicYearId,
    required this.academicYear,
    required this.monthStart,
    required this.status,
  });

  factory TenantMonthlyStatusModel.fromJson(Map<String, dynamic> j) =>
      TenantMonthlyStatusModel(
        id: (j['id'] ?? '') as String,
        tenantId: (j['tenantId'] ?? '') as String,
        academicYearId: (j['academicYearId'] ?? '') as String,
        academicYear: (j['academicYear'] ?? '') as String,
        monthStart: (j['monthStart'] ?? '') as String,
        status: (j['status'] ?? 'paid') as String,
      );
}

int _i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
