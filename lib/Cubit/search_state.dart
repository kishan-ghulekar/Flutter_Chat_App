import 'package:flutter/material.dart';

abstract class SearchState {}

class SearchInitialState extends SearchState {}

class SearchLoadingState extends SearchState {}

class SearchLoadedState extends SearchState {
  String res;
  SearchLoadedState({required this.res});
}

class SearchErrorState extends SearchState {
  String errorMsg;
  SearchErrorState({required this.errorMsg});
}
