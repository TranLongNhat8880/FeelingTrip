import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../models/review_model.dart';
import '../viewmodels/review_viewmodel.dart';

class ReviewFormScreen extends StatefulWidget {
  const ReviewFormScreen({
    super.key,
    required this.tripId,
    required this.tripName,
    this.revieweeId,
    this.revieweeName,
  });

  final String tripId;
  final String tripName;
  final String? revieweeId;
  final String? revieweeName;

  bool get isMemberReview => revieweeId != null;

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _commentController = TextEditingController();
  late final ReviewViewModel _viewModel;

  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _viewModel = ReviewViewModel();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final review = await _viewModel.submitReview(
      tripId: widget.tripId,
      revieweeId: widget.revieweeId,
      rating: _rating,
      comment: _commentController.text,
    );

    if (!mounted) return;

    if (review == null) {
      AppFeedback.show(
        context,
        _viewModel.errorMessage ?? 'Không thể gửi đánh giá.',
        tone: AppStatusTone.error,
      );
      return;
    }

    Navigator.pop<ReviewModel>(context, review);
  }

  @override
  Widget build(BuildContext context) {
    final targetName = widget.isMemberReview
        ? widget.revieweeName ?? 'thành viên này'
        : widget.tripName;

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => AppScaffold(
        title: widget.isMemberReview
            ? 'Đánh giá bạn đồng hành'
            : 'Đánh giá chuyến đi',
        scrollable: true,
        bottomAction: CustomButton(
          text: 'Gửi đánh giá',
          icon: Icons.send_outlined,
          width: double.infinity,
          isLoading: _viewModel.isSubmitting,
          onPressed: _viewModel.isSubmitting ? null : _submit,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: targetName,
                    subtitle: widget.isMemberReview
                        ? 'Đánh giá dựa trên trải nghiệm đồng hành trong ${widget.tripName}.'
                        : 'Chia sẻ cảm nhận sau khi chuyến đi hoàn thành.',
                  ),
                  const SizedBox(height: AppSizes.spaceL),
                  AppCard(
                    outlined: true,
                    child: Column(
                      children: [
                        Text(
                          'Mức độ hài lòng',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSizes.spaceM),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          children: [
                            for (var value = 1; value <= 5; value++)
                              IconButton(
                                tooltip: '$value sao',
                                iconSize: 38,
                                onPressed: _viewModel.isSubmitting
                                    ? null
                                    : () => setState(() => _rating = value),
                                icon: Icon(
                                  value <= _rating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: AppColors.star,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '$_rating/5 sao',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceL),
                  CustomTextField(
                    label: 'Nhận xét',
                    hint: widget.isMemberReview
                        ? 'Ví dụ: Đúng giờ, thân thiện và có trách nhiệm...'
                        : 'Điều gì khiến chuyến đi đáng nhớ?',
                    controller: _commentController,
                    prefixIcon: Icons.rate_review_outlined,
                    enabled: !_viewModel.isSubmitting,
                    maxLines: 6,
                    inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                    helperText: 'Không bắt buộc, tối đa 1000 ký tự.',
                    validator: (value) {
                      if ((value?.trim().length ?? 0) > 1000) {
                        return 'Nhận xét không được vượt quá 1000 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.spaceXL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
