import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toastification/toastification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/fish_product.dart';
import '../../services/fish_product_service.dart';
import '../../services/user_service.dart';
import 'fish_products_list_page.dart';

class FishScanningPage extends StatefulWidget {
  const FishScanningPage({super.key});

  @override
  State<FishScanningPage> createState() => _FishScanningPageState();
}

class _FishScanningPageState extends State<FishScanningPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _vesselNameController = TextEditingController();
  final _vesselRegistrationController = TextEditingController();
  final _vesselInfoController = TextEditingController();
  final _sizeController = TextEditingController();
  final _weightController = TextEditingController();

  File? _selectedImage;
  Uint8List? _webImageBytes;
  FishSpecies _selectedSpecies = FishSpecies.bangus;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userProfile = await UserService.getUserProfile(user.id);
      if (userProfile != null) {
        _fullNameController.text = userProfile.fullName;
      } else {
        // Create user profile if it doesn't exist
        await Supabase.instance.client.from('user_profiles').upsert({
          'user_id': user.id,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? 'Inspector User',
          'role': 'inspector',
          'is_active': true,
        }, onConflict: 'user_id');

        // Get the updated profile
        final updatedProfile = await UserService.getUserProfile(user.id);
        if (updatedProfile != null) {
          _fullNameController.text = updatedProfile.fullName;
        }
      }
    } catch (e) {
      // Fallback to user metadata if profile service fails
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.userMetadata?['full_name'] != null) {
        _fullNameController.text = user!.userMetadata!['full_name'] as String;
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _vesselNameController.dispose();
    _vesselRegistrationController.dispose();
    _vesselInfoController.dispose();
    _sizeController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _webImageBytes = null;
          });
        }
      }
    } catch (e) {
      _showToast('Failed to pick image: $e', ToastificationType.error);
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showToast('User not authenticated', ToastificationType.error);
        return;
      }

      final fishProduct = await FishProductService.createFishProduct(
        species: _selectedSpecies.name,
        size:
            _sizeController.text.trim().isEmpty
                ? null
                : _sizeController.text.trim(),
        weight:
            _weightController.text.trim().isEmpty
                ? null
                : double.tryParse(_weightController.text.trim()),
        vesselInfo:
            _vesselInfoController.text.trim().isEmpty
                ? null
                : _vesselInfoController.text.trim(),
        vesselName:
            _vesselNameController.text.trim().isEmpty
                ? null
                : _vesselNameController.text.trim(),
        vesselRegistration:
            _vesselRegistrationController.text.trim().isEmpty
                ? null
                : _vesselRegistrationController.text.trim(),
        imageFile: kIsWeb ? null : _selectedImage,
        imageBytes: kIsWeb ? _webImageBytes : null,
        inspectorId: user.id,
        inspectorName: _fullNameController.text.trim(),
      );

      if (fishProduct != null) {
        _showToast(
          'Fish product created successfully! Status: Pending',
          ToastificationType.success,
        );
        _resetForm();
      } else {
        _showToast('Failed to create fish product', ToastificationType.error);
      }
    } catch (e) {
      _showToast('Error: $e', ToastificationType.error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _vesselNameController.clear();
    _vesselRegistrationController.clear();
    _vesselInfoController.clear();
    _sizeController.clear();
    _weightController.clear();
    setState(() {
      _selectedImage = null;
      _webImageBytes = null;
      _selectedSpecies = FishSpecies.bangus;
    });
  }

  void _showToast(String message, ToastificationType type) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Blue Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    'Fish Scanning & Identification',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const FishProductsListPage(),
                      ),
                    );
                  },
                  tooltip: 'View Existing Products',
                ),
              ],
            ),
          ),
          // Page Content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(
                    constraints.maxWidth > 600 ? 24.0 : 16.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card (match Inspector Dashboard style)
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.05),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.02),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fish Product Inspection',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Capture fish photos and record product details',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Form Card
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Product Details',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 20),

                                // Responsive form layout
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 800) {
                                      // Two column layout for wide screens
                                      return Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: [
                                          SizedBox(
                                            width:
                                                (constraints.maxWidth - 32) / 2,
                                            child: _buildInspectorNameField(),
                                          ),
                                          SizedBox(
                                            width:
                                                (constraints.maxWidth - 32) / 2,
                                            child: _buildSpeciesDropdown(),
                                          ),
                                          SizedBox(
                                            width:
                                                (constraints.maxWidth - 32) / 2,
                                            child: _buildVesselNameField(),
                                          ),
                                          SizedBox(
                                            width:
                                                (constraints.maxWidth - 32) / 2,
                                            child:
                                                _buildVesselRegistrationField(),
                                          ),
                                          SizedBox(
                                            width:
                                                (constraints.maxWidth - 32) / 2,
                                            child: _buildSizeField(),
                                          ),
                                          SizedBox(
                                            width:
                                                (constraints.maxWidth - 32) / 2,
                                            child: _buildWeightField(),
                                          ),
                                          SizedBox(
                                            width: constraints.maxWidth - 32,
                                            child: _buildVesselInfoField(),
                                          ),
                                        ],
                                      );
                                    } else {
                                      // Single column layout for narrow screens
                                      return Column(
                                        children: [
                                          _buildInspectorNameField(),
                                          const SizedBox(height: 16),
                                          _buildSpeciesDropdown(),
                                          const SizedBox(height: 16),
                                          _buildVesselNameField(),
                                          const SizedBox(height: 16),
                                          _buildVesselRegistrationField(),
                                          const SizedBox(height: 16),
                                          _buildSizeField(),
                                          const SizedBox(height: 16),
                                          _buildWeightField(),
                                          const SizedBox(height: 16),
                                          _buildVesselInfoField(),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Image Capture Card
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fish Photo',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                _buildImageCaptureSection(),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _submitForm,
                            icon:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.save),
                            label: Text(
                              _isLoading
                                  ? 'Creating Product...'
                                  : 'Create Fish Product',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorNameField() {
    return TextFormField(
      controller: _fullNameController,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Inspector Name *',
        hintText: 'Loading inspector name...',
        prefixIcon: Icon(Icons.person),
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Color(0xFFF5F5F5),
      ),
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Inspector name is required';
        }
        return null;
      },
    );
  }

  Widget _buildSpeciesDropdown() {
    return DropdownButtonFormField<FishSpecies>(
      value: _selectedSpecies,
      decoration: const InputDecoration(
        labelText: 'Fish Species *',
        prefixIcon: Icon(Icons.pets),
        border: OutlineInputBorder(),
      ),
      items:
          FishSpecies.values.map((species) {
            return DropdownMenuItem<FishSpecies>(
              value: species,
              child: Text(species.displayName),
            );
          }).toList(),
      onChanged: (FishSpecies? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedSpecies = newValue;
          });
        }
      },
      validator: (value) {
        if (value == null) {
          return 'Please select a fish species';
        }
        return null;
      },
    );
  }

  Widget _buildVesselNameField() {
    return TextFormField(
      controller: _vesselNameController,
      decoration: const InputDecoration(
        labelText: 'Vessel Name',
        hintText: 'Enter vessel name',
        prefixIcon: Icon(Icons.directions_boat),
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildVesselRegistrationField() {
    return TextFormField(
      controller: _vesselRegistrationController,
      decoration: const InputDecoration(
        labelText: 'Vessel Registration',
        hintText: 'Enter registration number',
        prefixIcon: Icon(Icons.confirmation_number),
        border: OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildSizeField() {
    return TextFormField(
      controller: _sizeController,
      decoration: const InputDecoration(
        labelText: 'Size',
        hintText: 'e.g., Small, Medium, Large',
        prefixIcon: Icon(Icons.straighten),
        border: OutlineInputBorder(),
      ),
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      controller: _weightController,
      decoration: const InputDecoration(
        labelText: 'Weight (kg)',
        hintText: 'Enter weight in kilograms',
        prefixIcon: Icon(Icons.monitor_weight),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value != null && value.trim().isNotEmpty) {
          final weight = double.tryParse(value.trim());
          if (weight == null || weight <= 0) {
            return 'Please enter a valid weight';
          }
        }
        return null;
      },
    );
  }

  Widget _buildVesselInfoField() {
    return TextFormField(
      controller: _vesselInfoController,
      decoration: const InputDecoration(
        labelText: 'Additional Vessel Information',
        hintText: 'Enter any additional vessel details',
        prefixIcon: Icon(Icons.info_outline),
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildImageCaptureSection() {
    return Column(
      children: [
        if ((_selectedImage != null) || (_webImageBytes != null)) ...[
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  kIsWeb
                      ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                      : Image.file(_selectedImage!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Change Photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      _webImageBytes = null;
                    });
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
                width: 2,
              ),
              color: Colors.grey.shade50,
            ),
            child: InkWell(
              onTap: _showImageSourceDialog,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to capture or select photo',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Camera or Gallery',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
