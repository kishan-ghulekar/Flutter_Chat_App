import 'dart:convert';

import 'package:chat_app/Cubit/search_state.dart';
import 'package:chat_app/config/secrets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

class SearchCubit extends Cubit<SearchState> {
  static List<Map<String, dynamic>> chatList = [];
  SearchCubit() : super(SearchInitialState());

  void getSearchResponse({required String query}) async {
    emit(SearchLoadingState());

    chatList.add({
      "role": "user",
      "parts": [
        {"text": query}
      ]
    });

    String apiKey = Secrets.apiKey;
    String url =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey";

    Map<String, dynamic> bodyParams = {"contents": chatList};
    // Map<String, dynamic> bodyParams = {
    //   "contents": [
    //     {
    //       "parts": [
    //         {"text": query},
    //       ],
    //     },
    //   ],
    // };
    var response = await http.post(
      Uri.parse(url),
      body: jsonEncode(bodyParams),
    );

    if (response.statusCode == 200) {
      print(response.body);
      var data = jsonDecode(response.body);
      var res = data['candidates'][0]["content"]["parts"][0]["text"];
      chatList.add({
        "role": "model",
        "parts": [
          {"text": res}
        ]
      });
      emit(SearchLoadedState(res: res));
    } else {
      var error = "Error: ${response.statusCode}";
      emit(SearchErrorState(errorMsg: error));
    }
  }
}
