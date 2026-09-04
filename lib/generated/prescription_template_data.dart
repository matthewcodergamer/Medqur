import 'dart:convert';
import 'dart:typed_data';

/// Cleaned, tightly-cropped copy of the Southern Regional Health Authority /
/// Mandeville Regional Hospital prescription form supplied for the Medqur
/// prototype. It is embedded as source data so web, Android and iOS builds
/// render the exact same print template without a platform file-system path.
///
/// Template reference: SRHA.MRH.CM2013.
const String kPrescriptionTemplatePngBase64 = r'''
iVBORw0KGgoAAAANSUhEUgAAAnMAAARaCAAAAAAu9fnsAAEAAElEQVR42uz9B3hc13UeiJ0VKYRE
...