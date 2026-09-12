import 'package:dio/dio.dart';

import '../models/receipt_extraction_response_model.dart';

class ShoppingReceiptRemoteDataSource {
  final Dio dio;

  const ShoppingReceiptRemoteDataSource(this.dio);

  Future<ReceiptExtractionResponseModel> processNewReceipt({
    required String spaceId,
    required String imagePath,
    required String language,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imagePath),
      'language': language,
    });

    final response = await dio.post(
      '/api/v1/spaces/$spaceId/receipt-images',
      data: formData,
    );

    return ReceiptExtractionResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
