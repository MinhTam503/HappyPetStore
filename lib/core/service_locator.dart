import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Data sources
import 'package:pet_shop/data/datasources/chatbot_remote_datasource.dart';

// Repositories
import 'package:pet_shop/data/repositories/chatbot_repository_impl.dart';
import 'package:pet_shop/domain/repositories/chatbot_repository.dart';

// Use cases
import 'package:pet_shop/domain/usecases/send_chatbot_message_usecase.dart';
import 'package:pet_shop/domain/usecases/get_chatbot_history_usecase.dart';
import 'package:pet_shop/domain/usecases/save_chatbot_message_usecase.dart';
import 'package:pet_shop/domain/usecases/clear_chatbot_history_usecase.dart';

// BLoC
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_bloc.dart';


final serviceLocator = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  serviceLocator.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  serviceLocator.registerLazySingleton<http.Client>(() => http.Client());

  // Data sources
  serviceLocator.registerLazySingleton<ChatBotRemoteDataSource>(
    () => ChatBotRemoteDataSourceImpl(
      client: serviceLocator<http.Client>(),
    ),
  );

  // Repository
  serviceLocator.registerLazySingleton<ChatBotRepository>(
    () => ChatBotRepositoryImpl(
      remoteDataSource: serviceLocator<ChatBotRemoteDataSource>(),
      sharedPreferences: serviceLocator<SharedPreferences>(),
    ),
  );

  // Use cases
  serviceLocator.registerLazySingleton(() => SendChatBotMessageUseCase(serviceLocator<ChatBotRepository>()));
  serviceLocator.registerLazySingleton(() => GetChatBotHistoryUseCase(serviceLocator<ChatBotRepository>()));
  serviceLocator.registerLazySingleton(() => SaveChatBotMessageUseCase(serviceLocator<ChatBotRepository>()));
  serviceLocator.registerLazySingleton(() => ClearChatBotHistoryUseCase(serviceLocator<ChatBotRepository>()));

  // BLoC
  serviceLocator.registerFactory(
    () => ChatBotBloc(
      sendMessageUseCase: serviceLocator<SendChatBotMessageUseCase>(),
      getHistoryUseCase: serviceLocator<GetChatBotHistoryUseCase>(),
      saveMessageUseCase: serviceLocator<SaveChatBotMessageUseCase>(),
      clearHistoryUseCase: serviceLocator<ClearChatBotHistoryUseCase>(),
    ),
  );
}