import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/review_model.dart';
import '../repositories/api_review_repository.dart';
import '../repositories/review_repository.dart';

class ReviewViewModel extends ChangeNotifier {
  ReviewViewModel({ReviewRepository? repository})
    : _repository = repository ?? ApiReviewRepository();

  final ReviewRepository _repository;

  bool _isSubmitting = false;
  bool _isLoadingBlockedUsers = false;
  String? _updatingBlockedUserId;
  String? _errorMessage;
  List<BlockedUserModel> _blockedUsers = const [];

  bool get isSubmitting => _isSubmitting;
  bool get isLoadingBlockedUsers => _isLoadingBlockedUsers;
  String? get updatingBlockedUserId => _updatingBlockedUserId;
  String? get errorMessage => _errorMessage;
  List<BlockedUserModel> get blockedUsers => List.unmodifiable(_blockedUsers);

  Future<ReviewModel?> submitReview({
    required String tripId,
    String? revieweeId,
    required int rating,
    String? comment,
  }) async {
    if (_isSubmitting) return null;

    _setSubmitting(true);

    try {
      if (revieweeId == null) {
        return await _repository.reviewTrip(
          tripId: tripId,
          rating: rating,
          comment: comment,
        );
      }

      return await _repository.reviewMember(
        tripId: tripId,
        revieweeId: revieweeId,
        rating: rating,
        comment: comment,
      );
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể gửi đánh giá.');
      return null;
    } finally {
      _setSubmitting(false, keepError: true);
    }
  }

  Future<UserReportModel?> submitReport({
    String? reportedUserId,
    String? reportedTripId,
    required String reason,
    List<int>? evidenceBytes,
    String? evidenceFileName,
  }) async {
    if (_isSubmitting) return null;

    _setSubmitting(true);

    try {
      return await _repository.createReport(
        reportedUserId: reportedUserId,
        reportedTripId: reportedTripId,
        reason: reason,
        evidenceBytes: evidenceBytes,
        evidenceFileName: evidenceFileName,
      );
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể gửi báo cáo.');
      return null;
    } finally {
      _setSubmitting(false, keepError: true);
    }
  }

  Future<bool> blockUser(String userId) async {
    if (_isSubmitting) return false;

    _setSubmitting(true);

    try {
      await _repository.blockUser(userId);
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể chặn người dùng.');
      return false;
    } finally {
      _setSubmitting(false, keepError: true);
    }
  }

  Future<void> loadBlockedUsers() async {
    if (_isLoadingBlockedUsers) return;

    _isLoadingBlockedUsers = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _blockedUsers = await _repository.getBlockedUsers().timeout(
        const Duration(seconds: 20),
      );
    } catch (error) {
      _errorMessage = _messageFor(
        error,
        'Không thể tải danh sách người dùng đã chặn.',
      );
    } finally {
      _isLoadingBlockedUsers = false;
      notifyListeners();
    }
  }

  Future<bool> unblockUser(String userId) async {
    if (_updatingBlockedUserId != null) return false;

    _updatingBlockedUserId = userId;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.unblockUser(userId);
      _blockedUsers = _blockedUsers
          .where((user) => user.id != userId)
          .toList(growable: false);
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể bỏ chặn người dùng.');
      return false;
    } finally {
      _updatingBlockedUserId = null;
      notifyListeners();
    }
  }

  void _setSubmitting(bool value, {bool keepError = false}) {
    _isSubmitting = value;
    if (!keepError) _errorMessage = null;
    notifyListeners();
  }

  String _messageFor(Object error, String fallback) {
    if (error is ApiException) return error.message;
    if (error is TimeoutException) {
      return 'Kết nối quá lâu. Vui lòng thử lại.';
    }
    if (error is FormatException) return error.message;
    return fallback;
  }
}
