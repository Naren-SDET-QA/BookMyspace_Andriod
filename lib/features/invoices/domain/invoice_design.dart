/// Visual invoice designs. Tax amounts stay on the server snapshot.
enum InvoiceDesign {
  modernTeal('modern_teal', 'Modern Teal'),
  classicNavy('classic_navy', 'Classic Navy'),
  minimalMono('minimal_mono', 'Minimalist Monochrome'),
  corporateSlate('corporate_slate', 'Corporate Slate');

  const InvoiceDesign(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static InvoiceDesign parse(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    for (final design in InvoiceDesign.values) {
      if (design.storageValue == value || design.name == value) return design;
    }
    return InvoiceDesign.modernTeal;
  }
}
