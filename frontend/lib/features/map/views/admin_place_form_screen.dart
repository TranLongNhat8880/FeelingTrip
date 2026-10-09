import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../models/administrative_division_model.dart';
import '../models/place_form_data.dart';
import '../models/place_model.dart';
import '../repositories/administrative_division_repository.dart';
import '../viewmodels/admin_place_viewmodel.dart';

// ============================================================================
// VIEW: Form Admin thêm hoặc sửa địa điểm
// ============================================================================

class AdminPlaceFormScreen extends StatefulWidget {
  const AdminPlaceFormScreen({super.key, this.initialPlace});

  /// Có initialPlace: chế độ sửa.
  /// Không có initialPlace: chế độ thêm.
  final PlaceModel? initialPlace;

  @override
  State<AdminPlaceFormScreen> createState() => _AdminPlaceFormScreenState();
}

class _AdminPlaceFormScreenState extends State<AdminPlaceFormScreen> {
  static const int _maxImageSize = 5 * 1024 * 1024;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final AdminPlaceViewModel _viewModel;
  late final AdministrativeDivisionRepository _divisionRepository;
  late final TextEditingController _nameController;
  late final TextEditingController _destinationController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _durationController;

  late String _category;
  late int _priceLevel;
  AdministrativeDivisionVersion _divisionVersion =
      AdministrativeDivisionVersion.afterMerger;

  List<AdministrativeDivision> _provinces = const [];
  List<AdministrativeDivision> _districts = const [];
  List<AdministrativeDivision> _wards = const [];

  AdministrativeDivision? _selectedProvince;
  AdministrativeDivision? _selectedDistrict;
  AdministrativeDivision? _selectedWard;

  bool _isLoadingProvinces = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingWards = false;
  bool _addressSelectionChanged = false;
  String? _divisionErrorMessage;

  Uint8List? _imageBytes;
  String? _imageFileName;

  bool get _isEditing => widget.initialPlace != null;
  bool get _hasDistrictLevel => _divisionVersion.hasDistrictLevel;

  @override
  void initState() {
    super.initState();

    final place = widget.initialPlace;

    _viewModel = AdminPlaceViewModel();
    _divisionRepository = AdministrativeDivisionRepository();

    _nameController = TextEditingController(text: place?.name ?? '');
    _destinationController = TextEditingController(
      text: place?.destination ?? '',
    );
    _addressController = TextEditingController(text: place?.address ?? '');
    _latitudeController = TextEditingController(
      text: place?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: place?.longitude?.toString() ?? '',
    );
    _durationController = TextEditingController(
      text: (place?.avgDurationMinutes ?? 60).toString(),
    );

    _category = place?.category ?? 'ATTRACTION';
    _priceLevel = place?.priceLevel ?? 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProvinces();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _durationController.dispose();
    _divisionRepository.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    if (_isLoadingProvinces) return;

    final requestedVersion = _divisionVersion;

    setState(() {
      _isLoadingProvinces = true;
      _divisionErrorMessage = null;
    });

    try {
      final provinces = await _divisionRepository.getProvinces(
        requestedVersion,
      );
      if (!mounted || requestedVersion != _divisionVersion) return;

      final restoredProvince = _findMatchingDivision(
        provinces,
        _destinationController.text,
      );

      setState(() {
        _provinces = provinces;
        _selectedProvince = restoredProvince;
      });

      if (restoredProvince != null) {
        _destinationController.text = restoredProvince.name;
        if (requestedVersion.hasDistrictLevel) {
          await _loadDistricts(restoredProvince.code, restoreFromAddress: true);
        } else {
          await _loadWards(
            restoredProvince.code,
            fromProvince: true,
            restoreFromAddress: true,
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _divisionErrorMessage = _divisionErrorFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProvinces = false;
        });
      }
    }
  }

  Future<void> _loadDistricts(
    int provinceCode, {
    bool restoreFromAddress = false,
  }) async {
    setState(() {
      _isLoadingDistricts = true;
      _divisionErrorMessage = null;
    });

    try {
      final districts = await _divisionRepository.getDistricts(provinceCode);
      if (!mounted) return;

      final restoredDistrict = restoreFromAddress
          ? _findMatchingDivision(districts, _addressController.text)
          : null;

      setState(() {
        _districts = districts;
        _selectedDistrict = restoredDistrict;
        _wards = const [];
        _selectedWard = null;
      });

      if (restoredDistrict != null) {
        await _loadWards(
          restoredDistrict.code,
          fromProvince: false,
          restoreFromAddress: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _divisionErrorMessage = _divisionErrorFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDistricts = false;
        });
      }
    }
  }

  Future<void> _loadWards(
    int parentCode, {
    required bool fromProvince,
    bool restoreFromAddress = false,
  }) async {
    setState(() {
      _isLoadingWards = true;
      _divisionErrorMessage = null;
    });

    try {
      final wards = fromProvince
          ? await _divisionRepository.getWardsByProvince(parentCode)
          : await _divisionRepository.getWardsByDistrict(parentCode);
      if (!mounted) return;

      final restoredWard = restoreFromAddress
          ? _findMatchingDivision(wards, _addressController.text)
          : null;

      setState(() {
        _wards = wards;
        _selectedWard = restoredWard;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _divisionErrorMessage = _divisionErrorFor(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWards = false;
        });
      }
    }
  }

  Future<void> _onProvinceChanged(int? code) async {
    final province = _divisionByCode(_provinces, code);

    setState(() {
      _addressSelectionChanged = true;
      _selectedProvince = province;
      _selectedDistrict = null;
      _selectedWard = null;
      _districts = const [];
      _wards = const [];
      _destinationController.text = province?.name ?? '';
    });

    if (province != null) {
      if (_hasDistrictLevel) {
        await _loadDistricts(province.code);
      } else {
        await _loadWards(province.code, fromProvince: true);
      }
    }
  }

  Future<void> _onDistrictChanged(int? code) async {
    final district = _divisionByCode(_districts, code);

    setState(() {
      _addressSelectionChanged = true;
      _selectedDistrict = district;
      _selectedWard = null;
      _wards = const [];
    });

    if (district != null) {
      await _loadWards(district.code, fromProvince: false);
    }
  }

  Future<void> _onDivisionVersionChanged(
    AdministrativeDivisionVersion version,
  ) async {
    if (version == _divisionVersion) return;

    setState(() {
      _divisionVersion = version;
      _addressSelectionChanged = true;
      _provinces = const [];
      _districts = const [];
      _wards = const [];
      _selectedProvince = null;
      _selectedDistrict = null;
      _selectedWard = null;
      _destinationController.clear();
      _divisionErrorMessage = null;
    });

    await _loadProvinces();
  }

  void _onWardChanged(int? code) {
    setState(() {
      _addressSelectionChanged = true;
      _selectedWard = _divisionByCode(_wards, code);
    });
  }

  AdministrativeDivision? _divisionByCode(
    List<AdministrativeDivision> divisions,
    int? code,
  ) {
    if (code == null) return null;

    for (final division in divisions) {
      if (division.code == code) return division;
    }

    return null;
  }

  AdministrativeDivision? _findMatchingDivision(
    List<AdministrativeDivision> divisions,
    String source,
  ) {
    final normalizedSource = source.trim().toLowerCase();
    if (normalizedSource.isEmpty) return null;

    for (final division in divisions) {
      final normalizedName = division.name.trim().toLowerCase();
      final coreName = _divisionCoreName(normalizedName);
      if (normalizedSource == normalizedName ||
          normalizedSource.contains(normalizedName) ||
          normalizedName.contains(normalizedSource) ||
          (coreName.isNotEmpty && normalizedSource.contains(coreName))) {
        return division;
      }
    }

    return null;
  }

  String _divisionCoreName(String value) {
    return value.trim().toLowerCase().replaceFirst(
      RegExp(r'^(thành phố|tỉnh|quận|huyện|thị xã|phường|xã|thị trấn)\s+'),
      '',
    );
  }

  String _divisionErrorFor(Object error) {
    if (error is AdministrativeDivisionException) {
      return error.message;
    }

    if (error is FormatException) {
      return error.message;
    }

    return 'Không thể tải dữ liệu địa chỉ hành chính.';
  }

  bool get _mustChooseAllDivisions => !_isEditing || _addressSelectionChanged;

  String _composeAddress() {
    final parts = <String>[];

    void addPart(String? rawValue) {
      final value = rawValue?.trim() ?? '';
      if (value.isEmpty) return;

      final normalizedValue = value.toLowerCase();
      final coreValue = _divisionCoreName(normalizedValue);

      final alreadyIncluded = parts.any(
        (part) =>
            part.toLowerCase().contains(normalizedValue) ||
            (coreValue.isNotEmpty && part.toLowerCase().contains(coreValue)),
      );

      if (!alreadyIncluded) {
        parts.add(value);
      }
    }

    addPart(_addressController.text);
    addPart(_selectedWard?.name);
    addPart(_selectedDistrict?.name);
    addPart(_selectedProvince?.name);

    return parts.join(', ');
  }

  Future<void> _retryDivisionLoad() async {
    if (!_hasDistrictLevel && _selectedProvince != null && _wards.isEmpty) {
      await _loadWards(_selectedProvince!.code, fromProvince: true);
      return;
    }

    if (_selectedDistrict != null && _wards.isEmpty) {
      await _loadWards(_selectedDistrict!.code, fromProvince: false);
      return;
    }

    if (_selectedProvince != null && _districts.isEmpty) {
      await _loadDistricts(_selectedProvince!.code);
      return;
    }

    await _loadProvinces();
  }

  Widget _buildDivisionDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required List<AdministrativeDivision> items,
    required AdministrativeDivision? selected,
    required bool loading,
    required bool enabled,
    required ValueChanged<int?> onChanged,
    required String requiredMessage,
    bool requiredField = true,
  }) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-${selected?.code}-${items.length}'),
      initialValue: selected?.code,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      hint: Text(loading ? 'Đang tải...' : hint),
      items: items
          .map(
            (division) => DropdownMenuItem<int>(
              value: division.code,
              child: Text(division.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: enabled && !loading ? onChanged : null,
      validator: (_) {
        if (requiredField && selected == null) {
          return requiredMessage;
        }
        return null;
      },
    );
  }

  Future<void> _pickImage() async {
    if (_viewModel.isSaving) return;

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (pickedFile == null) return;

    final fileName = pickedFile.name;
    final extension = fileName.split('.').last.toLowerCase();

    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      if (!mounted) return;

      AppFeedback.show(
        context,
        'Ảnh phải có định dạng JPG, JPEG, PNG hoặc WEBP.',
        tone: AppStatusTone.error,
      );
      return;
    }

    final bytes = await pickedFile.readAsBytes();

    if (bytes.length > _maxImageSize) {
      if (!mounted) return;

      AppFeedback.show(
        context,
        'Dung lượng ảnh không được vượt quá 5 MB.',
        tone: AppStatusTone.error,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _imageBytes = bytes;
      _imageFileName = fileName;
    });
  }

  void _removeSelectedImage() {
    if (_viewModel.isSaving) return;

    setState(() {
      _imageBytes = null;
      _imageFileName = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final destinationError = _validateDestination(_destinationController.text);

    if (destinationError != null) {
      AppFeedback.show(context, destinationError, tone: AppStatusTone.error);
      return;
    }

    final latitudeText = _latitudeController.text.trim();
    final longitudeText = _longitudeController.text.trim();

    if (latitudeText.isEmpty != longitudeText.isEmpty) {
      AppFeedback.show(
        context,
        'Vui lòng nhập đồng thời cả vĩ độ và kinh độ.',
        tone: AppStatusTone.error,
      );
      return;
    }

    final composedAddress = _composeAddress();

    if (composedAddress.length > 500) {
      AppFeedback.show(
        context,
        'Địa chỉ đầy đủ không được vượt quá 500 ký tự.',
        tone: AppStatusTone.error,
      );
      return;
    }

    final formData = PlaceFormData(
      name: _nameController.text,
      destination: _destinationController.text,
      address: composedAddress,
      category: _category,
      latitude: latitudeText.isEmpty ? null : double.parse(latitudeText),
      longitude: longitudeText.isEmpty ? null : double.parse(longitudeText),
      priceLevel: _priceLevel,
      avgDurationMinutes: int.parse(_durationController.text.trim()),
    );

    final PlaceModel? savedPlace;

    if (_isEditing) {
      savedPlace = await _viewModel.updatePlace(
        placeId: widget.initialPlace!.id,
        data: formData,
        imageBytes: _imageBytes,
        imageFileName: _imageFileName,
      );
    } else {
      savedPlace = await _viewModel.createPlace(
        data: formData,
        imageBytes: _imageBytes,
        imageFileName: _imageFileName,
      );
    }

    if (!mounted) return;

    if (savedPlace == null) {
      AppFeedback.show(
        context,
        _viewModel.errorMessage ?? 'Không thể lưu địa điểm.',
        tone: AppStatusTone.error,
      );
      return;
    }

    Navigator.pop(context, savedPlace);
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Tên địa điểm là bắt buộc';
    }

    if (text.length < 2) {
      return 'Tên địa điểm phải có ít nhất 2 ký tự';
    }

    if (text.length > 255) {
      return 'Tên địa điểm không được vượt quá 255 ký tự';
    }

    return null;
  }

  String? _validateDestination(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Tỉnh hoặc thành phố là bắt buộc';
    }

    if (text.length < 2) {
      return 'Tên tỉnh hoặc thành phố phải có ít nhất 2 ký tự';
    }

    if (text.length > 100) {
      return 'Tên tỉnh hoặc thành phố không được vượt quá 100 ký tự';
    }

    return null;
  }

  String? _validateAddress(String? value) {
    if ((value?.trim().length ?? 0) > 500) {
      return 'Địa chỉ không được vượt quá 500 ký tự';
    }

    return null;
  }

  String? _validateLatitude(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    final latitude = double.tryParse(text);

    if (latitude == null) {
      return 'Vĩ độ phải là số';
    }

    if (latitude < -90 || latitude > 90) {
      return 'Vĩ độ phải nằm trong khoảng -90 đến 90';
    }

    return null;
  }

  String? _validateLongitude(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    final longitude = double.tryParse(text);

    if (longitude == null) {
      return 'Kinh độ phải là số';
    }

    if (longitude < -180 || longitude > 180) {
      return 'Kinh độ phải nằm trong khoảng -180 đến 180';
    }

    return null;
  }

  String? _validateDuration(String? value) {
    final duration = int.tryParse(value?.trim() ?? '');

    if (duration == null) {
      return 'Thời lượng phải là số phút nguyên';
    }

    if (duration < 10 || duration > 720) {
      return 'Thời lượng phải nằm trong khoảng 10 đến 720 phút';
    }

    return null;
  }

  Widget? _buildImagePreview() {
    if (_imageBytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
          ),
          AttachmentPreview(
            name: _imageFileName ?? 'Ảnh địa điểm',
            onRemove: _removeSelectedImage,
          ),
        ],
      );
    }

    final existingImageUrl = widget.initialPlace?.imageUrl;

    if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
      return AppImage(
        url: existingImageUrl,
        semanticLabel: 'Ảnh hiện tại của địa điểm',
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final isSaving = _viewModel.isSaving;

        return AppScaffold(
          title: _isEditing ? 'Sửa địa điểm' : 'Thêm địa điểm',
          scrollable: true,
          bottomAction: CustomButton(
            text: _isEditing ? 'Lưu thay đổi' : 'Thêm địa điểm',
            icon: _isEditing
                ? Icons.save_outlined
                : Icons.add_location_alt_outlined,
            width: double.infinity,
            isLoading: isSaving,
            onPressed: isSaving ? null : _submit,
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.documentMaxWidth,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: _isEditing
                          ? 'Cập nhật địa điểm'
                          : 'Thông tin địa điểm',
                      subtitle: _isEditing
                          ? 'Chỉnh sửa thông tin đang lưu trong kho địa điểm.'
                          : 'Thêm địa điểm mới vào kho dùng chung của hệ thống.',
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    ImagePickerField(
                      label:
                          _imageBytes == null &&
                              widget.initialPlace?.imageUrl == null
                          ? 'Chọn ảnh địa điểm'
                          : 'Chọn ảnh khác',
                      enabled: !isSaving,
                      onPick: _pickImage,
                      preview: _buildImagePreview(),
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    CustomTextField(
                      label: 'Tên địa điểm',
                      hint: 'Ví dụ: Hồ Hoàn Kiếm',
                      controller: _nameController,
                      prefixIcon: Icons.place_outlined,
                      enabled: !isSaving,
                      validator: _validateName,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    Text(
                      'Địa chỉ hành chính',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.spaceXS),
                    Text(
                      _hasDistrictLevel
                          ? 'Dữ liệu trước 07/2025 gồm tỉnh/thành phố, quận/huyện và phường/xã.'
                          : 'Dữ liệu sau 07/2025 gồm tỉnh/thành phố và phường/xã.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSizes.spaceM),
                    AppChoiceChips<AdministrativeDivisionVersion>(
                      options: _divisionVersionOptions,
                      selected: {_divisionVersion},
                      enabled:
                          !isSaving &&
                          !_isLoadingProvinces &&
                          !_isLoadingDistricts &&
                          !_isLoadingWards,
                      onChanged: _onDivisionVersionChanged,
                    ),
                    if (_divisionErrorMessage != null) ...[
                      const SizedBox(height: AppSizes.spaceM),
                      AppInlineNotice(
                        message: _divisionErrorMessage!,
                        tone: AppStatusTone.error,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _retryDivisionLoad,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tải lại dữ liệu địa chỉ'),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSizes.spaceM),
                    _buildDivisionDropdown(
                      label: 'Tỉnh hoặc thành phố',
                      hint: 'Chọn tỉnh hoặc thành phố',
                      icon: Icons.location_city_outlined,
                      items: _provinces,
                      selected: _selectedProvince,
                      loading: _isLoadingProvinces,
                      enabled:
                          !isSaving &&
                          !_isLoadingDistricts &&
                          !_isLoadingWards &&
                          _provinces.isNotEmpty,
                      onChanged: _onProvinceChanged,
                      requiredMessage: 'Vui lòng chọn tỉnh hoặc thành phố',
                      requiredField:
                          !_isEditing ||
                          _destinationController.text.trim().isEmpty,
                    ),
                    if (_hasDistrictLevel) ...[
                      const SizedBox(height: AppSizes.spaceM),
                      _buildDivisionDropdown(
                        label: 'Quận hoặc huyện',
                        hint: _selectedProvince == null
                            ? 'Chọn tỉnh/thành phố trước'
                            : 'Chọn quận hoặc huyện',
                        icon: Icons.map_outlined,
                        items: _districts,
                        selected: _selectedDistrict,
                        loading: _isLoadingDistricts,
                        enabled:
                            !isSaving &&
                            !_isLoadingWards &&
                            _selectedProvince != null &&
                            _districts.isNotEmpty,
                        onChanged: _onDistrictChanged,
                        requiredMessage: 'Vui lòng chọn quận hoặc huyện',
                        requiredField: _mustChooseAllDivisions,
                      ),
                    ],
                    const SizedBox(height: AppSizes.spaceM),
                    _buildDivisionDropdown(
                      label: 'Phường hoặc xã',
                      hint: _hasDistrictLevel
                          ? (_selectedDistrict == null
                                ? 'Chọn quận/huyện trước'
                                : 'Chọn phường hoặc xã')
                          : (_selectedProvince == null
                                ? 'Chọn tỉnh/thành phố trước'
                                : 'Chọn phường hoặc xã'),
                      icon: Icons.holiday_village_outlined,
                      items: _wards,
                      selected: _selectedWard,
                      loading: _isLoadingWards,
                      enabled:
                          !isSaving &&
                          (_hasDistrictLevel
                              ? _selectedDistrict != null
                              : _selectedProvince != null) &&
                          _wards.isNotEmpty,
                      onChanged: _onWardChanged,
                      requiredMessage: 'Vui lòng chọn phường hoặc xã',
                      requiredField: _mustChooseAllDivisions,
                    ),
                    const SizedBox(height: AppSizes.spaceM),
                    CustomTextField(
                      label: 'Địa chỉ chi tiết',
                      hint: 'Ví dụ: Số 58, đường Quốc Tử Giám',
                      controller: _addressController,
                      prefixIcon: Icons.signpost_outlined,
                      enabled: !isSaving,
                      validator: _validateAddress,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    Text(
                      'Danh mục',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.spaceS),
                    AppChoiceChips<String>(
                      options: _categoryOptions,
                      selected: {_category},
                      enabled: !isSaving,
                      onChanged: (value) {
                        setState(() {
                          _category = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    Text(
                      'Mức giá',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.spaceS),
                    AppChoiceChips<int>(
                      options: _priceOptions,
                      selected: {_priceLevel},
                      enabled: !isSaving,
                      onChanged: (value) {
                        setState(() {
                          _priceLevel = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    CustomTextField(
                      label: 'Thời lượng tham quan trung bình',
                      hint: 'Số phút, từ 10 đến 720',
                      controller: _durationController,
                      prefixIcon: Icons.schedule_outlined,
                      enabled: !isSaving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateDuration,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSizes.spaceL),
                    Text(
                      'Tọa độ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.spaceXS),
                    Text(
                      'Có thể bỏ trống, nhưng nếu nhập thì phải nhập đủ cả hai.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSizes.spaceM),
                    CustomTextField(
                      label: 'Vĩ độ',
                      hint: 'Ví dụ: 21.028666',
                      controller: _latitudeController,
                      prefixIcon: Icons.north_outlined,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: _validateLatitude,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSizes.spaceM),
                    CustomTextField(
                      label: 'Kinh độ',
                      hint: 'Ví dụ: 105.852148',
                      controller: _longitudeController,
                      prefixIcon: Icons.east_outlined,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: _validateLongitude,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSizes.spaceXL),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const Map<AdministrativeDivisionVersion, String> _divisionVersionOptions = {
  AdministrativeDivisionVersion.beforeMerger: 'Trước sáp nhập 07/2025',
  AdministrativeDivisionVersion.afterMerger: 'Sau sáp nhập 07/2025',
};

const Map<String, String> _categoryOptions = {
  'ATTRACTION': 'Tham quan',
  'RESTAURANT': 'Ăn uống',
  'CAFE': 'Cà phê',
  'HOTEL': 'Khách sạn',
  'ENTERTAINMENT': 'Giải trí',
  'NATURE': 'Thiên nhiên',
  'CULTURE': 'Văn hóa',
  'SHOPPING': 'Mua sắm',
  'OTHER': 'Khác',
};

const Map<int, String> _priceOptions = {
  1: 'Tiết kiệm',
  2: 'Vừa phải',
  3: 'Cao cấp',
  4: 'Sang trọng',
};
