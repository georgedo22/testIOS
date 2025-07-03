import 'package:flutter/material.dart';
import 'package:habibuv2/InventoryApp/api_service.dart';
import 'package:habibuv2/InventoryApp/spare_part.dart';

class EditPartForm extends StatefulWidget {
  final SparePart part;
  final Function(SparePart) onSave;
  final VoidCallback onCancel;

  EditPartForm({
    required this.part,
    required this.onSave,
    required this.onCancel,
  });

  @override
  _EditPartFormState createState() => _EditPartFormState();
}

class _EditPartFormState extends State<EditPartForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _partNameController;
  late TextEditingController _partCodeController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _storageLocationController;
  late TextEditingController _minimumThresholdController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _partNameController = TextEditingController(text: widget.part.partName);
    _partCodeController = TextEditingController(text: widget.part.partCode);
    _quantityController =
        TextEditingController(text: widget.part.quantity.toString());
    _priceController =
        TextEditingController(text: widget.part.price.toString());
    _storageLocationController =
        TextEditingController(text: widget.part.storageLocation);
    _minimumThresholdController =
        TextEditingController(text: widget.part.minimumThreshold.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _partNameController,
            label: 'Part Name',
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          SizedBox(height: 12),
          _buildTextField(
            controller: _partCodeController,
            label: 'Part Code',
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          SizedBox(height: 12),
          _buildTextField(
            controller: _quantityController,
            label: 'Quantity',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Required';
              if (int.tryParse(value!) == null) return 'Invalid number';
              return null;
            },
          ),
          SizedBox(height: 12),
          _buildTextField(
            controller: _priceController,
            label: 'Price',
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Required';
              if (double.tryParse(value!) == null) return 'Invalid price';
              return null;
            },
          ),
          SizedBox(height: 12),
          _buildTextField(
            controller: _storageLocationController,
            label: 'Storage Location',
          ),
          SizedBox(height: 12),
          _buildTextField(
            controller: _minimumThresholdController,
            label: 'Minimum Threshold',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value?.isNotEmpty ?? false) {
                if (int.tryParse(value!) == null) return 'Invalid number';
              }
              return null;
            },
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.indigo, width: 2),
        ),
      ),
    );
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      final updatedPart = SparePart(
        id: widget.part.id,
        partName: _partNameController.text,
        partCode: _partCodeController.text,
        quantity: int.parse(_quantityController.text),
        price: double.parse(_priceController.text),
        storageLocation: _storageLocationController.text,
        minimumThreshold: int.tryParse(_minimumThresholdController.text) ?? 5,
        governorate_id: widget.part.governorate_id,
      );
      final success = await ApiService.updatePart(updatedPart);
      setState(() {
        _isLoading = false;
      });
      if (success) {
        widget.onSave(updatedPart);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Part updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update part'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _partNameController.dispose();
    _partCodeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _storageLocationController.dispose();
    _minimumThresholdController.dispose();
    super.dispose();
  }
}
