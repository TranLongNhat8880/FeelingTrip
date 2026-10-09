import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../models/review_model.dart';
import '../repositories/api_review_repository.dart';
import '../repositories/review_repository.dart';

class EmergencyContactsViewModel extends ChangeNotifier {
  EmergencyContactsViewModel({ReviewRepository? repository})
    : _repository = repository ?? ApiReviewRepository();

  final ReviewRepository _repository;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _deletingContactId;
  String? _errorMessage;
  List<EmergencyContactModel> _contacts = const [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get deletingContactId => _deletingContactId;
  String? get errorMessage => _errorMessage;
  List<EmergencyContactModel> get contacts => List.unmodifiable(_contacts);

  Future<void> loadContacts() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _contacts = await _repository.getEmergencyContacts().timeout(
        const Duration(seconds: 20),
      );
    } catch (error) {
      _errorMessage = _messageFor(
        error,
        'Không thể tải danh sách liên hệ khẩn cấp.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveContact({
    EmergencyContactModel? contact,
    required String fullName,
    required String phone,
    String? relationship,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final saved = contact == null
          ? await _repository.createEmergencyContact(
              fullName: fullName,
              phone: phone,
              relationship: relationship,
            )
          : await _repository.updateEmergencyContact(
              contactId: contact.id,
              fullName: fullName,
              phone: phone,
              relationship: relationship,
            );

      if (contact == null) {
        _contacts = [saved, ..._contacts];
      } else {
        _contacts = _contacts
            .map((item) => item.id == saved.id ? saved : item)
            .toList(growable: false);
      }
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể lưu người liên hệ.');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteContact(String contactId) async {
    if (_deletingContactId != null) return false;

    _deletingContactId = contactId;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteEmergencyContact(contactId);
      _contacts = _contacts
          .where((contact) => contact.id != contactId)
          .toList(growable: false);
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error, 'Không thể xóa người liên hệ.');
      return false;
    } finally {
      _deletingContactId = null;
      notifyListeners();
    }
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
