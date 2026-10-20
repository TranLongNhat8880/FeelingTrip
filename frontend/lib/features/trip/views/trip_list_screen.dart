import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/ui_kit.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../viewmodels/trip_viewmodel.dart';
import 'trip_detail_screen.dart';
import 'trip_form_screen.dart';
import 'widgets/trip_widgets.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key, this.repository});
  final TripRepository? repository;

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  late final TripViewModel _viewModel;
  String? _status;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = TripViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..loadTrips();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    _search.dispose();
    super.dispose();
  }

  List<TripModel> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _viewModel.trips
        .where(
          (trip) =>
              trip.membershipStatus == 'ACTIVE' &&
              (_status == null || trip.status == _status) &&
              (query.isEmpty ||
                  '${trip.name} ${trip.destination}'.toLowerCase().contains(
                    query,
                  )),
        )
        .toList();
  }

  Future<void> _create() async {
    KoharuScope.maybeOf(context)?.tapped('trip.create');
    final result = await Navigator.push<TripModel>(
      context,
      MaterialPageRoute(
        builder: (_) => TripFormScreen(repository: _viewModel.repository),
      ),
    );
    if (result != null && mounted) {
      AppFeedback.show(
        context,
        'Đã tạo chuyến đi. Bắt đầu thêm lịch trình hoặc mời thành viên nhé.',
        tone: AppStatusTone.success,
      );
      await _open(result);
    }
  }

  Future<void> _join() async {
    final result = await AppBottomSheet.show<TripModel>(
      context,
      title: 'Tham gia bằng mã',
      child: _JoinTripForm(viewModel: _viewModel),
    );
    if (!mounted || result == null) return;
    await _viewModel.loadTrips();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          tripId: result.id,
          repository: _viewModel.repository,
        ),
      ),
    );
    await _viewModel.loadTrips();
  }

  Future<void> _open(TripModel trip) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          tripId: trip.id,
          repository: _viewModel.repository,
        ),
      ),
    );
    await _viewModel.loadTrips();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Chuyến đi của tôi',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final createButton = CustomButton(
              text: 'Tạo chuyến đi',
              guideId: 'trip.create',
              icon: Icons.add_rounded,
              onPressed: _create,
            );
            final joinButton = ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: CustomButton(
                text: 'Tham gia bằng mã',
                icon: Icons.key_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: _join,
              ),
            );
            final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
            if (constraints.maxWidth < 480 * textScale) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  createButton,
                  const SizedBox(height: 10),
                  joinButton,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: createButton),
                  const SizedBox(width: 10),
                  Expanded(child: joinButton),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        AppSearchField(
          controller: _search,
          hint: 'Tìm tên chuyến đi hoặc điểm đến',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: AppChoiceChips<String>(
            options: const {
              'ALL': 'Tất cả',
              'UPCOMING': 'Sắp đi',
              'ONGOING': 'Đang đi',
              'COMPLETED': 'Đã kết thúc',
              'CANCELLED': 'Đã hủy',
            },
            selected: {_status ?? 'ALL'},
            onChanged: (value) {
              FocusScope.of(context).unfocus();
              setState(() => _status = value == 'ALL' ? null : value);
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_visible.length} chuyến đi',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (_viewModel.errorMessage != null && _viewModel.trips.isNotEmpty)
          AppInlineNotice(
            message: _viewModel.errorMessage!,
            tone: AppStatusTone.error,
          ),
        const SizedBox(height: 12),
        Expanded(child: _content()),
      ],
    ),
  );

  Widget _content() {
    if (_viewModel.isLoading && _viewModel.trips.isEmpty) {
      return const Center(
        child: LoadingIndicator(message: 'Đang tải chuyến đi...'),
      );
    }
    if (_viewModel.errorMessage != null && _viewModel.trips.isEmpty) {
      return ErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadTrips,
      );
    }
    if (_visible.isEmpty) {
      return SingleChildScrollView(
        child: EmptyStateWidget(
          icon: Icons.flight_takeoff_rounded,
          title: _status == null && _search.text.isEmpty
              ? 'Chưa có chuyến đi'
              : 'Không có chuyến phù hợp',
          message: _status == null && _search.text.isEmpty
              ? 'Tạo hành trình đầu tiên hoặc tham gia nhóm bằng mã mời.'
              : 'Hãy thử chọn một trạng thái khác.',
          buttonText: _status == null && _search.text.isEmpty
              ? 'Tạo chuyến đi'
              : 'Xóa bộ lọc',
          onButtonPressed: _status == null && _search.text.isEmpty
              ? _create
              : () => setState(() {
                  _status = null;
                  _search.clear();
                }),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _viewModel.loadTrips,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) => TripCard(
          trip: _visible[index],
          onTap: () {
            KoharuScope.maybeOf(context)?.tapped('trip.open');
            _open(_visible[index]);
          },
        ).koharu(index == 0 ? 'trip.open' : null),
      ),
    );
  }
}

class _JoinTripForm extends StatefulWidget {
  const _JoinTripForm({required this.viewModel});
  final TripViewModel viewModel;

  @override
  State<_JoinTripForm> createState() => _JoinTripFormState();
}

class _JoinTripFormState extends State<_JoinTripForm> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final trip = await widget.viewModel.joinByCode(_code.text);
    if (!mounted) return;
    if (trip != null) {
      Navigator.pop(context, trip);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppInlineNotice(
          message: 'Mã gồm 6 ký tự và chỉ dùng được một lần.',
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Mã tham gia',
          hint: 'A1B2C3',
          controller: _code,
          prefixIcon: Icons.key_outlined,
          inputFormatters: [
            LengthLimitingTextInputFormatter(6),
            FilteringTextInputFormatter.allow(RegExp('[a-fA-F0-9]')),
            _UpperCaseFormatter(),
          ],
          validator: (value) => (value ?? '').length == 6
              ? null
              : 'Mã tham gia phải có đúng 6 ký tự',
        ),
        if (widget.viewModel.errorMessage != null) ...[
          const SizedBox(height: 12),
          AppInlineNotice(
            message: widget.viewModel.errorMessage!,
            tone: AppStatusTone.error,
          ),
        ],
        const SizedBox(height: 20),
        CustomButton(
          text: 'Tham gia chuyến đi',
          isLoading: widget.viewModel.isSubmitting,
          onPressed: widget.viewModel.isSubmitting ? null : _submit,
        ),
      ],
    ),
  );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
