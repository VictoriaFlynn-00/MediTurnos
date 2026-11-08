import 'config.dart';
import 'connectivity_service.dart';
import '../data/datasources/local_db.dart';
import '../data/datasources/mock_remote_data_source.dart';
import '../data/datasources/remote_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/sync_manager.dart';
import '../data/repositories/turno_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/turno_repository.dart';
import '../domain/usecases/auth_usecases.dart';
import '../domain/usecases/turno_usecases.dart';

/// Contenedor de dependencias (inyección manual, sin librerías extra).
class Di {
  late final ConnectivityService connectivity;
  late final LocalDb db;
  late final RemoteDataSource remote;
  late final SyncManager sync;
  late final AuthRepository authRepo;
  late final TurnoRepository turnoRepo;

  late final IniciarSesionUseCase iniciarSesion;
  late final RegistrarPacienteUseCase registrarPaciente;
  late final BuscarPacienteUseCase buscarPaciente;
  late final ActualizarPerfilUseCase actualizarPerfil;
  late final RestaurarSesionUseCase restaurarSesion;
  late final CerrarSesionUseCase cerrarSesion;

  late final ConsultarEspecialistasUseCase especialistas;
  late final ConsultarEspecialidadesUseCase especialidades;
  late final ConsultarDisponibilidadUseCase disponibilidad;
  late final SolicitarTurnoUseCase solicitarTurno;
  late final CancelarTurnoUseCase cancelarTurno;
  late final ConsultarHistorialUseCase historial;
  late final SincronizarTurnosUseCase sincronizar;
  late final BorradorTurnoUseCase borrador;

  static Future<Di> crear() async {
    final di = Di();
    di.connectivity = ConnectivityService();
    await di.connectivity.init();
    di.db = LocalDb();

    if (kUsarMock) {
      di.remote = MockRemoteDataSource(() => di.connectivity.online);
    } else {
      // TODO(sesión siguiente): HttpRemoteDataSource(kApiBaseUrl, tokens)
      throw UnimplementedError('Cliente HTTP pendiente. Usá kUsarMock = true.');
    }

    di.sync = SyncManager(di.db, di.remote, di.connectivity);
    di.authRepo = AuthRepositoryImpl(di.remote, di.db, SecureTokenStorage());
    di.turnoRepo = TurnoRepositoryImpl(di.db, di.remote, di.connectivity, di.sync);

    di.iniciarSesion = IniciarSesionUseCase(di.authRepo);
    di.registrarPaciente = RegistrarPacienteUseCase(di.authRepo);
    di.buscarPaciente = BuscarPacienteUseCase(di.authRepo);
    di.actualizarPerfil = ActualizarPerfilUseCase(di.authRepo);
    di.restaurarSesion = RestaurarSesionUseCase(di.authRepo);
    di.cerrarSesion = CerrarSesionUseCase(di.authRepo);

    di.especialistas = ConsultarEspecialistasUseCase(di.turnoRepo);
    di.especialidades = ConsultarEspecialidadesUseCase(di.turnoRepo);
    di.disponibilidad = ConsultarDisponibilidadUseCase(di.turnoRepo);
    di.solicitarTurno = SolicitarTurnoUseCase(di.turnoRepo);
    di.cancelarTurno = CancelarTurnoUseCase(di.turnoRepo);
    di.historial = ConsultarHistorialUseCase(di.turnoRepo);
    di.sincronizar = SincronizarTurnosUseCase(di.turnoRepo);
    di.borrador = BorradorTurnoUseCase(di.turnoRepo);

    // Al arrancar: si quedaron operaciones pendientes y hay red, se envían.
    di.sincronizar();
    return di;
  }
}
