import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../models/review_model.dart';
import '../viewmodels/emergency_contacts_viewmodel.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  late final EmergencyContactsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = EmergencyContactsViewModel()..loadContacts();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openForm([EmergencyContactModel? contact]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !_viewModel.isSaving,
      builder: (_) =>
          _EmergencyContactFormDialog(viewModel: _viewModel, contact: contact),
    );

    if (!mounted || saved != true) return;
    AppFeedback.show(
      context,
      contact == null
          ? 'Đã thêm người liên hệ khẩn cấp.'
          : 'Đã cập nhật người liên hệ.',
      tone: AppStatusTone.success,
    );
  }

  Future<void> _delete(EmergencyContactModel contact) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Xóa ${contact.fullName}?',
      message: 'Người này sẽ không còn trong danh bạ khẩn cấp của bạn.',
      confirmLabel: 'Xóa liên hệ',
      destructive: true,
    );

    if (!confirmed) return;
    final success = await _viewModel.deleteContact(contact.id);

    if (!mounted) return;
    AppFeedback.show(
      context,
      success
          ? 'Đã xóa ${contact.fullName}.'
          : _viewModel.errorMessage ?? 'Không thể xóa người liên hệ.',
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => AppScaffold(
        title: 'Liên hệ khẩn cấp',
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _viewModel.isLoading ? null : _viewModel.loadContacts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottomAction: CustomButton(
          text: 'Thêm liên hệ',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: _viewModel.isSaving ? null : _openForm,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.contacts.isEmpty) {
      return const LoadingIndicator(message: 'Đang tải danh bạ khẩn cấp...');
    }

    if (_viewModel.errorMessage != null && _viewModel.contacts.isEmpty) {
      return ErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadContacts,
      );
    }

    if (_viewModel.contacts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.contact_emergency_outlined,
        title: 'Chưa có liên hệ khẩn cấp',
        message:
            'Thêm người thân hoặc bạn bè để chuẩn bị cho tình huống cần hỗ trợ.',
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.loadContacts,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: AppSizes.spaceM, bottom: 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _viewModel.contacts.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spaceM),
        itemBuilder: (context, index) {
          final contact = _viewModel.contacts[index];
          final deleting = _viewModel.deletingContactId == contact.id;

          return AppCard(
            outlined: true,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  child: Icon(Icons.contact_emergency_outlined),
                ),
                const SizedBox(width: AppSizes.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(contact.phone),
                      if (contact.relationship != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          contact.relationship!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !deleting,
                  tooltip: 'Tùy chọn',
                  onSelected: (value) {
                    if (value == 'edit') _openForm(contact);
                    if (value == 'delete') _delete(contact);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Chỉnh sửa'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Xóa'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmergencyContactFormDialog extends StatefulWidget {
  const _EmergencyContactFormDialog({required this.viewModel, this.contact});

  final EmergencyContactsViewModel viewModel;
  final EmergencyContactModel? contact;

  @override
  State<_EmergencyContactFormDialog> createState() =>
      _EmergencyContactFormDialogState();
}

class _EmergencyContactFormDialogState
    extends State<_EmergencyContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _relationshipController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.fullName);
    _phoneController = TextEditingController(text: widget.contact?.phone);
    _relationshipController = TextEditingController(
      text: widget.contact?.relationship,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.viewModel.saveContact(
      contact: widget.contact,
      fullName: _nameController.text,
      phone: _phoneController.text,
      relationship: _relationshipController.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      return;
    }

    AppFeedback.show(
      context,
      widget.viewModel.errorMessage ?? 'Không thể lưu người liên hệ.',
      tone: AppStatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) => Dialog(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.contact == null
                            ? 'Thêm liên hệ khẩn cấp'
                            : 'Chỉnh sửa liên hệ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: widget.viewModel.isSaving
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceM),
                CustomTextField(
                  label: 'Họ và tên',
                  hint: 'Ví dụ: Nguyễn Văn An',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 2) return 'Tên phải có ít nhất 2 ký tự';
                    if (text.length > 100) return 'Tên không quá 100 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spaceM),
                CustomTextField(
                  label: 'Số điện thoại',
                  hint: 'Ví dụ: 0912345678',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(phone)) {
                      return 'Nhập 9–15 chữ số, có thể bắt đầu bằng +';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spaceM),
                CustomTextField(
                  label: 'Mối quan hệ (không bắt buộc)',
                  hint: 'Ví dụ: Bố, mẹ, bạn thân',
                  controller: _relationshipController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  validator: (value) => (value?.trim().length ?? 0) > 100
                      ? 'Mối quan hệ không quá 100 ký tự'
                      : null,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: widget.contact == null
                      ? 'Thêm liên hệ'
                      : 'Lưu thay đổi',
                  icon: Icons.save_outlined,
                  isLoading: widget.viewModel.isSaving,
                  onPressed: widget.viewModel.isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
