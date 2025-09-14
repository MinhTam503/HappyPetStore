import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Data Sources
import 'package:pet_shop/data/datasources/chatbot_remote_datasource.dart';

// Repositories
import 'package:pet_shop/data/repositories/chatbot_repository_impl.dart';
import 'package:pet_shop/domain/repositories/chatbot_repository.dart';

// Use Cases
import 'package:pet_shop/domain/usecases/send_chatbot_message_usecase.dart';
import 'package:pet_shop/domain/usecases/get_chatbot_history_usecase.dart';
import 'package:pet_shop/domain/usecases/save_chatbot_message_usecase.dart';
import 'package:pet_shop/domain/usecases/clear_chatbot_history_usecase.dart';

// BLoC
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> initializeChatBotDependencies() async {
  // External dependencies
  if (!sl.isRegistered<SharedPreferences>()) {
    final sharedPreferences = await SharedPreferences.getInstance();
    sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  }
  
  if (!sl.isRegistered<http.Client>()) {
    sl.registerLazySingleton<http.Client>(() => http.Client());
  }

  // Data sources
  sl.registerLazySingleton<ChatBotRemoteDataSource>(
    () => ChatBotRemoteDataSourceImpl(
      client: sl<http.Client>(),
    ),
  );

  // Repository
  sl.registerLazySingleton<ChatBotRepository>(
    () => ChatBotRepositoryImpl(
      remoteDataSource: sl<ChatBotRemoteDataSource>(),
      sharedPreferences: sl<SharedPreferences>(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => SendChatBotMessageUseCase(sl<ChatBotRepository>()));
  sl.registerLazySingleton(() => GetChatBotHistoryUseCase(sl<ChatBotRepository>()));
  sl.registerLazySingleton(() => SaveChatBotMessageUseCase(sl<ChatBotRepository>()));
  sl.registerLazySingleton(() => ClearChatBotHistoryUseCase(sl<ChatBotRepository>()));

  // BLoC
  sl.registerFactory(
    () => ChatBotBloc(
      sendMessageUseCase: sl<SendChatBotMessageUseCase>(),
      getHistoryUseCase: sl<GetChatBotHistoryUseCase>(),
      saveMessageUseCase: sl<SaveChatBotMessageUseCase>(),
      clearHistoryUseCase: sl<ClearChatBotHistoryUseCase>(),
    ),
  );
}