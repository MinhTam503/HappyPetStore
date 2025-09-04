import '../../../data/repositories/apriori_repository_impl.dart';
import '../../../domain/repositories/apriori_repository.dart';
import '../../../domain/usecases/apriori_usecase.dart';
import '../../../presentation/bloc/apriori/apriori_bloc.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final AprioriRepository _aprioriRepository;
  late final AprioriUseCase _aprioriUseCase;

  void setup() {
    _aprioriRepository = AprioriRepositoryImpl();
    _aprioriUseCase = AprioriUseCase(_aprioriRepository);
  }

  AprioriRepository get aprioriRepository => _aprioriRepository;
  AprioriUseCase get aprioriUseCase => _aprioriUseCase;
  
  AprioriBloc createAprioriBloc() => AprioriBloc(_aprioriUseCase);
}

final serviceLocator = ServiceLocator();
