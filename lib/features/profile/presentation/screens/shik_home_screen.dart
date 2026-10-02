import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

const _ink = Color(0xFF172D38);
const _muted = Color(0xFF7A9099);
const _sky = Color(0xFF13A9D6);
const _line = Color(0xFFE6EEF1);

class _Product {
  const _Product({
    required this.barcode,
    required this.name,
    required this.price,
    required this.unit,
  });

  final String barcode;
  final String name;
  final double price;
  final String unit;

  _Product copyWith({double? price}) => _Product(
        barcode: barcode,
        name: name,
        price: price ?? this.price,
        unit: unit,
      );
}

const _catalog = {
  '6281000001234': _Product(
    barcode: '6281000001234',
    name: 'قهوة عربية 250 غرام',
    price: 24.50,
    unit: 'عبوة',
  ),
  '6281000005678': _Product(
    barcode: '6281000005678',
    name: 'مياه معدنية 1.5 لتر',
    price: 2.00,
    unit: 'حبة',
  ),
  '6281000009012': _Product(
    barcode: '6281000009012',
    name: 'شاي أخضر 100 غرام',
    price: 12.75,
    unit: 'عبوة',
  ),
};

class ShikHomeScreen extends StatefulWidget {
  const ShikHomeScreen({super.key});

  @override
  State<ShikHomeScreen> createState() => _ShikHomeScreenState();
}

class _ShikHomeScreenState extends State<ShikHomeScreen> {
  final _barcodeController = TextEditingController();
  _Product? _product;
  String? _printerName;
  bool _busy = false;

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  void _loadBarcode(String rawBarcode) {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) return;
    setState(() {
      _barcodeController.text = barcode;
      _product = _catalog[barcode] ??
          _Product(
            barcode: barcode,
            name: 'منتج جديد',
            price: 0,
            unit: 'حبة',
          );
    });
  }

  Future<void> _openScanner() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ScannerScreen()),
    );
    if (barcode != null && mounted) _loadBarcode(barcode);
  }

  Future<void> _editPrice() async {
    final product = _product;
    if (product == null) return;
    final price = await showDialog<double>(
      context: context,
      builder: (_) => _PriceDialog(initialPrice: product.price),
    );
    if (price != null && mounted) {
      setState(() => _product = product.copyWith(price: price));
    }
  }

  Future<void> _selectPrinter() async {
    final permission = await Permission.bluetoothConnect.request();
    if (!permission.isGranted) {
      _showMessage('اسمح بالوصول إلى Bluetooth من إعدادات الجهاز.');
      return;
    }
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      _showMessage('فعّل Bluetooth ثم حاول مرة أخرى.');
      return;
    }
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    if (!mounted) return;
    if (devices.isEmpty) {
      _showMessage('اقرن الطابعة من إعدادات Bluetooth أولاً.');
      return;
    }
    final selectedMac = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر الطابعة',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...devices.map(
                (device) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F8FC),
                    child: Icon(Icons.print_rounded, color: _sky),
                  ),
                  title: Text(device.name, textAlign: TextAlign.right),
                  subtitle: Text(device.macAdress, textAlign: TextAlign.right),
                  onTap: () => Navigator.pop(sheetContext, device.macAdress),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selectedMac == null) return;
    final device = devices.firstWhere((item) => item.macAdress == selectedMac);
    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: selectedMac,
    );
    if (!mounted) return;
    setState(() => _printerName = connected ? device.name : null);
    _showMessage(
      connected ? 'تم الاتصال بـ ${device.name}' : 'تعذر الاتصال بالطابعة.',
    );
  }

  Future<void> _printProduct() async {
    final product = _product;
    if (product == null || product.price <= 0) {
      _showMessage('أدخل سعر المنتج أولاً.');
      return;
    }
    setState(() => _busy = true);
    try {
      var connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        await _selectPrinter();
        connected = await PrintBluetoothThermal.connectionStatus;
      }
      if (!connected) return;

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = <int>[]
        ..addAll(generator.reset())
        ..addAll(generator.setGlobalCodeTable('CP864'))
        ..addAll(
          generator.text(
            'شيك',
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
            linesAfter: 1,
          ),
        )
        ..addAll(
          generator.text(
            product.name,
            styles: const PosStyles(align: PosAlign.center),
          ),
        )
        ..addAll(
          generator.text(
            'السعر: ${product.price.toStringAsFixed(2)}',
            styles: const PosStyles(align: PosAlign.center, bold: true),
            linesAfter: 1,
          ),
        )
        ..addAll(
          generator.text(
            product.barcode,
            styles: const PosStyles(align: PosAlign.center),
          ),
        )
        )
        ..addAll(
          generator.barcode(Barcode.code128(product.barcode.codeUnits)),
        ..addAll(generator.feed(3));
      final printed = await PrintBluetoothThermal.writeBytes(bytes);
      if (mounted) {
        _showMessage(printed ? 'تم إرسال الإيصال للطباعة.' : 'فشلت الطباعة.');
      }
    } catch (_) {
      if (mounted) _showMessage('تعذر الطباعة. تحقق من اتصال الطابعة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message, textAlign: TextAlign.right)));
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _sky,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('شيك',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: IconButton.filledTonal(
                tooltip: 'اختيار الطابعة',
                onPressed: _selectPrinter,
                icon: const Icon(Icons.print_rounded),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const Text(
                'فحص المنتجات',
                style: TextStyle(
                  color: _ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'امسح الباركود، راجع السعر، واطبع مباشرة.',
                style: TextStyle(color: _muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _PrinterStatus(
                printerName: _printerName,
                onTap: _selectPrinter,
              ),
              const SizedBox(height: 22),
              _SectionLabel(
                title: 'رقم الباركود',
                trailing: TextButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 19),
                  label: const Text('افتح الكاميرا'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _barcodeController,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                keyboardType: TextInputType.number,
                onSubmitted: _loadBarcode,
                decoration: InputDecoration(
                  hintText: 'أدخل الرقم يدوياً',
                  hintStyle: const TextStyle(color: _muted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted),
                  suffixIcon: IconButton(
                    tooltip: 'بحث',
                    onPressed: () => _loadBarcode(_barcodeController.text),
                    icon: const Icon(Icons.arrow_forward_rounded, color: _sky),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _sky, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel(
                title: 'بيانات المنتج',
                trailing: product == null ? null : const _DemoTag(),
              ),
              const SizedBox(height: 8),
              if (product == null)
                const _EmptyProduct()
              else ...[
                _ProductPanel(product: product, onEditPrice: _editPrice),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _printProduct,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_rounded),
                    label: Text(_busy ? 'جارٍ الإرسال...' : 'طباعة السعر'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _sky,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const _SectionLabel(title: 'للتجربة السريعة'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _catalog.values
                    .map(
                      (sample) => ActionChip(
                        avatar: const Icon(Icons.inventory_2_outlined,
                            size: 16, color: _sky),
                        label: Text(sample.name),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onPressed: () => _loadBarcode(sample.barcode),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('مسح الباركود'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled || capture.barcodes.isEmpty) return;
              final value = capture.barcodes.first.rawValue;
              if (value == null || value.isEmpty) return;
              _handled = true;
              Navigator.of(context).pop(value);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 270,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: _sky, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              'وجّه الكاميرا نحو الباركود',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.initialPrice});

  final double initialPrice;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final _controller = TextEditingController(
    text: widget.initialPrice == 0 ? '' : widget.initialPrice.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تعديل سعر المنتج'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'السعر',
            suffixText: 'ر.س',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(_controller.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('حفظ السعر'),
          ),
        ],
      ),
    );
  }
}

class _PrinterStatus extends StatelessWidget {
  const _PrinterStatus({required this.printerName, required this.onTap});

  final String? printerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connected = printerName != null;
    return Material(
      color: connected ? const Color(0xFFEAF8F1) : const Color(0xFFEAF7FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                connected ? Icons.bluetooth_connected : Icons.bluetooth,
                color: connected ? const Color(0xFF25845A) : _sky,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'الطابعة متصلة' : 'لا توجد طابعة متصلة',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      printerName ?? 'اضغط لاختيار طابعة Bluetooth مقترنة',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _DemoTag extends StatelessWidget {
  const _DemoTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'بيانات محلية',
        style: TextStyle(
          color: Color(0xFF94630A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductPanel extends StatelessWidget {
  const _ProductPanel({required this.product, required this.onEditPrice});

  final _Product product;
  final VoidCallback onEditPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7FB),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: _sky, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.barcode,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1, color: _line),
          ),
          Row(
            children: [
              const Text('سعر البيع', style: TextStyle(color: _muted)),
              const Spacer(),
              Text(
                '${product.price.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'تعديل السعر',
                onPressed: onEditPrice,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF7FB),
                  foregroundColor: _sky,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text('الوحدة: ${product.unit}',
              style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyProduct extends StatelessWidget {
  const _EmptyProduct();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 38, color: _sky),
          SizedBox(height: 8),
          Text(
            'امسح منتجاً للبدء',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'ستظهر بيانات المنتج وسعره هنا',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}