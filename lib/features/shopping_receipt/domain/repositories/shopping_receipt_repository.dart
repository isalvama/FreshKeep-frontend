import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/receipt_extraction_result.dart';

abstract class ShoppingReceiptRepository {
  Future<Either<ShoppingReceiptFailure, ReceiptExtractionResult>> processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  });
}
