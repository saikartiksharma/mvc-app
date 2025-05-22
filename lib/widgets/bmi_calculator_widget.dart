// lib/widgets/bmi_calculator_widget.dart
import 'package:flutter/material.dart';

class BMICalculatorWidget extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const BMICalculatorWidget({Key? key, this.userData}) : super(key: key);

  @override
  _BMICalculatorWidgetState createState() => _BMICalculatorWidgetState();
}

class _BMICalculatorWidgetState extends State<BMICalculatorWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  double? _bmi;
  String _bmiCategory = '';
  Color _bmiColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    if (widget.userData != null) {
      _heightController.text = widget.userData!['height']?.toString() ?? '';
      _weightController.text = widget.userData!['weight']?.toString() ?? '';
    }
  }

  @override
  void didUpdateWidget(covariant BMICalculatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userData != oldWidget.userData && widget.userData != null) {
      bool heightChanged =_heightController.text != (widget.userData!['height']?.toString() ?? '');
      bool weightChanged = _weightController.text != (widget.userData!['weight']?.toString() ?? '');

      if(heightChanged) _heightController.text = widget.userData!['height']?.toString() ?? '';
      if(weightChanged) _weightController.text = widget.userData!['weight']?.toString() ?? '';
    }
  }

  void _calculateBmi() {
    if (_formKey.currentState!.validate()) {
      final height = double.tryParse(_heightController.text);
      final weight = double.tryParse(_weightController.text);

      if (height != null && weight != null && height > 0) {
        final heightInMeters = height / 100;
        final calculatedBmi = weight / (heightInMeters * heightInMeters);
        if(mounted) {
          setState(() {
            _bmi = calculatedBmi;
            if (calculatedBmi < 18.5) {
              _bmiCategory = 'Underweight';
              _bmiColor = Colors.blue.shade300;
            } else if (calculatedBmi < 25) {
              _bmiCategory = 'Normal';
              _bmiColor = Colors.green.shade400;
            } else if (calculatedBmi < 30) {
              _bmiCategory = 'Overweight';
              _bmiColor = Colors.orange.shade400;
            } else {
              _bmiCategory = 'Obese';
              _bmiColor = Colors.red.shade400;
            }
          });
        }
      } else {
        if(mounted) {
          setState(() {
            _bmi = null;
            _bmiCategory = '';
            _bmiColor = Colors.grey;
          });
        }
      }
    } else {
      if(mounted) {
        setState(() {
          _bmi = null;
          _bmiCategory = '';
          _bmiColor = Colors.grey;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('BMI Calculator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _heightController,
                decoration: InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.height)),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter height';
                  if (double.tryParse(value) == null || double.parse(value) <= 0 || double.parse(value) > 300) return 'Invalid height';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.line_weight)),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter weight';
                  if (double.tryParse(value) == null || double.parse(value) <= 0 || double.parse(value) > 500) return 'Invalid weight';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calculate BMI'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                onPressed: _calculateBmi,
              ),
              if (_bmi != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text('Your BMI is', style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        _bmi!.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: _bmiColor),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _bmiColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _bmiCategory,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: _bmiColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}