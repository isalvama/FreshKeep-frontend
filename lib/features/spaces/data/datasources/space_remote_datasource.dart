import 'package:dio/dio.dart';

import '../models/create_space_request_model.dart';
import '../models/space_invitation_response_model.dart';
import '../models/space_response_model.dart';

class SpaceRemoteDataSource {
  final Dio dio;

  const SpaceRemoteDataSource(this.dio);

  Future<SpaceResponseModel> createSpace(CreateSpaceRequestModel request) async {
    final response = await dio.post('/api/v1/spaces', data: request.toJson());
    return SpaceResponseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SpaceResponseModel>> getSpaces() async {
    final response = await dio.get('/api/v1/spaces');
    return (response.data as List<dynamic>)
        .map((json) => SpaceResponseModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<SpaceInvitationResponseModel> createInvitation(String spaceId) async {
    final response = await dio.post('/api/v1/spaces/$spaceId/invitations');
    return SpaceInvitationResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
