import 'package:flutter_test/flutter_test.dart';
import 'package:yevmiye_defterim/features/workers/data/worker.dart';

void main() {
  group('Worker.fromDoc', () {
    test('tam veri okunur', () {
      final w = Worker.fromDoc('id1', {
        'name': 'Ahmet',
        'type': 'sabit',
        'gender': 'male',
        'dailyWageOverrideKurus': 210000,
        'active': true,
      });
      expect(w.id, 'id1');
      expect(w.name, 'Ahmet');
      expect(w.type, WorkerType.sabit);
      expect(w.gender, Gender.male);
      expect(w.dailyWageOverrideKurus, 210000);
      expect(w.active, true);
    });

    test('eksik alanlar güvenli varsayılana düşer', () {
      final w = Worker.fromDoc('id2', {'name': 'Zehra'});
      expect(w.type, WorkerType.gundelik); // varsayılan tür
      expect(w.gender, Gender.male); // varsayılan cinsiyet
      expect(w.dailyWageOverrideKurus, isNull); // override yok
      expect(w.active, true); // varsayılan aktif
    });

    test('null veri => boş isim, aktif', () {
      final w = Worker.fromDoc('id3', null);
      expect(w.name, '');
      expect(w.active, true);
    });

    test('bilinmeyen tür/cinsiyet güvenli varsayılana düşer', () {
      final w = Worker.fromDoc('id4', {'type': 'xxx', 'gender': 'yyy'});
      expect(w.type, WorkerType.gundelik);
      expect(w.gender, Gender.male);
    });

    test('override double gelirse int kuruşa iner', () {
      final w = Worker.fromDoc('id5', {'dailyWageOverrideKurus': 210000.0});
      expect(w.dailyWageOverrideKurus, 210000);
      expect(w.dailyWageOverrideKurus, isA<int>());
    });

    test('elebaşı kişi sayısı (defaultHeadcount) okunur', () {
      final w = Worker.fromDoc('id7', {'type': 'elebasi', 'defaultHeadcount': 5});
      expect(w.defaultHeadcount, 5);
      expect(w.crewSize, 5);
    });

    test('kişi sayısı yoksa null, gösterilmez (0)', () {
      final w = Worker.fromDoc('id8', {'type': 'elebasi'});
      expect(w.defaultHeadcount, isNull);
      expect(w.crewSize, 0);
    });

    test('active:false okunur (soft-delete)', () {
      final w = Worker.fromDoc('id6', {'name': 'X', 'active': false});
      expect(w.active, false);
    });
  });

  group('Worker.toMap round-trip', () {
    test('override null korunur', () {
      const w = Worker(
        id: 'a',
        name: 'Ali',
        type: WorkerType.gundelik,
        gender: Gender.male,
      );
      final back = Worker.fromDoc('a', w.toMap());
      expect(back, w);
      expect(back.dailyWageOverrideKurus, isNull);
    });

    test('elebaşı türü korunur', () {
      const w = Worker(
        id: 'e',
        name: 'Usta',
        type: WorkerType.elebasi,
        gender: Gender.male,
      );
      expect(Worker.fromDoc('e', w.toMap()), w);
    });

    test('elebaşı kişi sayısı round-trip korunur', () {
      const w = Worker(
        id: 'e2',
        name: 'Reis',
        type: WorkerType.elebasi,
        gender: Gender.male,
        defaultHeadcount: 7,
      );
      final back = Worker.fromDoc('e2', w.toMap());
      expect(back, w);
      expect(back.defaultHeadcount, 7);
    });
  });

  group('crewSize — gösterilecek ekip mevcudu', () {
    Worker crew(int? hc) => Worker(
          id: 'c',
          name: 'Reis',
          type: WorkerType.elebasi,
          gender: Gender.male,
          defaultHeadcount: hc,
        );

    test('elebaşı >0 => değerin kendisi', () {
      expect(crew(5).crewSize, 5);
    });
    test('elebaşı null/0 => 0 (gösterilmez)', () {
      expect(crew(null).crewSize, 0);
      expect(crew(0).crewSize, 0);
    });
    test('bireysel işçide kişi sayısı yok sayılır (0)', () {
      const ind = Worker(
        id: 'i',
        name: 'Ali',
        type: WorkerType.gundelik,
        gender: Gender.male,
        defaultHeadcount: 5, // bireyselde anlamsız
      );
      expect(ind.crewSize, 0);
    });
  });

  group('compareWorkers — sıralama', () {
    Worker mk(String name, WorkerType type) =>
        Worker(id: name, name: name, type: type, gender: Gender.male);

    test('önce tür (sabit<gündelik<elebaşı), sonra ad', () {
      final list = [
        mk('Zeki', WorkerType.elebasi),
        mk('Bekir', WorkerType.gundelik),
        mk('Ahmet', WorkerType.gundelik),
        mk('Veli', WorkerType.sabit),
      ]..sort(compareWorkers);
      expect(list.map((w) => w.name).toList(),
          ['Veli', 'Ahmet', 'Bekir', 'Zeki']);
    });

    test('aynı tür içinde ad büyük/küçük harf duyarsız', () {
      final list = [
        mk('bekir', WorkerType.sabit),
        mk('Ahmet', WorkerType.sabit),
      ]..sort(compareWorkers);
      expect(list.map((w) => w.name).toList(), ['Ahmet', 'bekir']);
    });
  });

  group('WorkerType davranışı', () {
    test('elebaşı isCrew, bireysel değil', () {
      expect(WorkerType.elebasi.isCrew, true);
      expect(WorkerType.elebasi.isIndividual, false);
    });
    test('sabit/gündelik bireysel', () {
      expect(WorkerType.sabit.isIndividual, true);
      expect(WorkerType.gundelik.isIndividual, true);
      expect(WorkerType.sabit.isCrew, false);
    });
  });
}
