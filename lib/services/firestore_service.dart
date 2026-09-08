import 'package:cloud_firestore/cloud_firestore.dart';

class PerformanceModel {
  final String id;
  final String title;
  final String genre;
  final String videoUrl;
  final int score;
  final String duration;
  final DateTime date;
  final double wer;
  final int tempo;
  final Map<String, double> emotions;
  final List<Map<String, String>> suggestions;
  final int? voiceScore;
  final int? emotionScore;
  final int? textScore;
  final int? geminiScore;
  final String? status;

  PerformanceModel({
    required this.id,
    required this.title,
    required this.genre,
    required this.videoUrl,
    required this.score,
    required this.duration,
    required this.date,
    required this.wer,
    required this.tempo,
    required this.emotions,
    required this.suggestions,
    this.voiceScore,
    this.emotionScore,
    this.textScore,
    this.geminiScore,
    this.status,
  });

  factory PerformanceModel.fromMap(String id, Map<String, dynamic> data) {
    return PerformanceModel(
      id: id,
      title: data['title'] ?? 'İsimsiz Performans',
      genre: data['genre'] ?? 'Genel',
      videoUrl: data['videoUrl'] ?? '',
      score: data['score'] ?? 0,
      duration: data['duration'] ?? '00:00',
      date: data['date'] != null
          ? (data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : (data['date'] is String
                  ? DateTime.tryParse(data['date'] as String) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
      wer: (data['wer'] ?? 4.2).toDouble(),
      tempo: data['tempo'] ?? 128,
      emotions: Map<String, double>.from(
        (data['emotions'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      suggestions: List<Map<String, String>>.from(
        (data['suggestions'] ?? []).map((item) => Map<String, String>.from(item as Map)),
      ),
      voiceScore: data['voice_score'],
      emotionScore: data['emotion_score'],
      textScore: data['text_score'],
      geminiScore: data['gemini_score'],
      status: data['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'genre': genre,
      'videoUrl': videoUrl,
      'score': score,
      'duration': duration,
      'date': Timestamp.fromDate(date),
      'wer': wer,
      'tempo': tempo,
      'emotions': emotions,
      'suggestions': suggestions,
      'voice_score': voiceScore,
      'emotion_score': emotionScore,
      'text_score': textScore,
      'gemini_score': geminiScore,
      'status': status,
    };
  }
}

class TriadModel {
  final String id;
  final String name;
  final String title;
  final String author;
  final String desc;
  final String rules;
  final String script;
  final String targetEmotion;
  final String difficulty;
  final String duration;
  final String imageUrl;
  final String aiScore;

  TriadModel({
    required this.id,
    required this.name,
    required this.title,
    required this.author,
    required this.desc,
    required this.rules,
    required this.script,
    required this.targetEmotion,
    required this.difficulty,
    required this.duration,
    required this.imageUrl,
    required this.aiScore,
  });

  factory TriadModel.fromMap(String id, Map<String, dynamic> data) {
    return TriadModel(
      id: id,
      name: data['name'] ?? '',
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      desc: data['desc'] ?? '',
      rules: data['rules'] ?? '',
      script: data['script'] ?? '',
      targetEmotion: data['targetEmotion'] ?? '',
      difficulty: data['difficulty'] ?? '',
      duration: data['duration'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      aiScore: data['aiScore'] ?? '90%',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'title': title,
      'author': author,
      'desc': desc,
      'rules': rules,
      'script': script,
      'targetEmotion': targetEmotion,
      'difficulty': difficulty,
      'duration': duration,
      'imageUrl': imageUrl,
      'aiScore': aiScore,
    };
  }
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get all triads (seeds them if collection is empty)
  Future<List<TriadModel>> getTriads() async {
    try {
      final snapshot = await _db.collection('triads').get();
      if (snapshot.docs.isEmpty) {
        await seedTriads();
        final newSnapshot = await _db.collection('triads').get();
        return newSnapshot.docs.map((doc) => TriadModel.fromMap(doc.id, doc.data())).toList();
      }
      return snapshot.docs.map((doc) => TriadModel.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      print("Error fetching triads: $e");
      // Fallback to local hardcoded list if firestore fails
      return _staticTriads;
    }
  }

  // Seed triads database
  Future<void> seedTriads() async {
    final batch = _db.batch();
    for (final triad in _staticTriads) {
      final docRef = _db.collection('triads').doc(triad.id);
      batch.set(docRef, triad.toMap());
    }
    await batch.commit();
  }

  static final List<TriadModel> _staticTriads = [
    TriadModel(
      id: 'ophelia',
      name: 'Ophelia',
      title: 'Ophelia (Polonius\'un Kızı)',
      author: 'William Shakespeare',
      desc: 'Oyuncu monolog boyunca karakterin zihinsel karmaşasını, ani duygu geçişlerini ve melankolik yapısını yansıtmalıdır.',
      rules: 'Oyuncu monolog boyunca karakterin zihinsel karmaşasını, ani duygu geçişlerini ve melankolik yapısını yansıtmalıdır.',
      script: 'Nasıl ayırdederim bir bakışta\nSeveni sevmeyenden?\nKülahından, tozlu çarıklarından,\nElindeki değnekten.\nÖldü, güzel sultanım çoktan öldü.\nÖldü, gömüldü bile.\nBaşında yemyeşil otlar büyüdü,\nTaşı dikildi bile.\nNe olur dinleyin!\nAk kefenler giyindi kardan beyaz,\nSarıldı çiçeklere.\nArar arar sevdiğini bulamaz,\nAğlayanlar içinde.\n[Kahkaha]\nFırıncının kızı baykuş olmuş diyorlar.\nAllah korusun.\nİnsan ne olduğunu bilir, ama ne olacağını bilemez.\nTanrı bereketini eksik etmesin sofranızdan.\nKendiniz hiçbir söz söylemeyin sakın bunun üstüne, ama ne demek olduğunu soran olursa şöyle dersiniz:\nYarın bayram, Saint Valentine bayramı,\nErken uyanır herkes.\nBen bir kızım, gelirim pencerene,\nEşim ol derim sana.\nDelikanlı kalktı, hemen giyindi,\nAçtı kıza kapısını.\nKız girdi içeri, kız girdi ama,\nKız çıkmadı dışarı.\nAyıp, ne ayıp şey bu!\nFırsat bulan her genç yapıyor bunu\nYüzü kızarmaksızın.\nKız dedi: Bu işi yapmazdan önce\nEvleniriz demiştin?\nDelikanlı şöyle karşılık verdi:\nEvlenirdim sabah sabah gelip de\nKoynuma girmeseydin.\nElbet bir gün düzelir her şey.\nİnsan sabırlı olmalı;\nEvet ama ağlamamak elimde değil\nDüşündükçe soğuk topraklara gömüldüğünü.\nGeceniz hayrolsun, bayanlar, iyi geceler,\nGüzel bayanlar, iyi geceler,\nİyi geceler, iyi geceler!',
      targetEmotion: 'Melankoli / Karmaşık',
      difficulty: 'İleri',
      duration: '3dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCw9pMJSDsCkdOVITlRhHP9ZYf5VGOrdjuAaZ-EnFbb6zg-_yrOx3AXxUEEgDhx-EWN_sDGJ8wQXhGTJPRsVCLXTc0jkB_-EHVIVJcIGMommQE7IWQ1QaDB1ev3HJlvgh0AY4v-eEJxqrjvpcEFTqTmNJCGl8BLgY1FIG76M0N4z5p45I3QSK0Jbo0LHF1vhakNh0qzi9CLXYqosimEcZKGU-xjm_7gIu4BDMGM2pcw4ZtMP54oLpH2sUdSNTHgiHNpC1XxgKiXiiQ',
      aiScore: '95%',
    ),
    TriadModel(
      id: 'gulseren',
      name: 'Gülseren',
      title: 'Gülseren (Yılmaz Erdoğan)',
      author: 'Yılmaz Erdoğan',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu içten, saf ve çocuksu bir dertleşme tonu yakalamalı, hüzün ile naif tebessümler arasındaki geçişi dengeli sunmalıdır.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu içten, saf ve çocuksu bir dertleşme tonu yakalamalı, hüzün ile naif tebessümler arasındaki geçişi dengeli sunmalıdır.',
      script: 'Tanrım seninle biraz konuşmak istiyorum.\nYalnız Türkçe konuşabilir miyiz? Üzgünüm, ben\nArapça bilmiyorum da. Kürşat dayım senin\nyalnızca Arapça bildiğini düşünüyor. Ama sen bizim Tanrımızsın ve bütün dilleri bilirsin. Tanrım, ben babamı yanına alışın konusunda konuşmak istiyorum. Kızmazsın umarım. Çünkü senin bu çeşit konuşmalardan hoşlanmadığını söylüyorlar. Ama bu işte biraz aceleci davranmadın mı? Babam biraz daha bizimle kalabilirdi bence. Ama onu yanına aldığına göre, bir bildiğin vardır mutlaka. Tanrı\'nın neyi niçin yaptığına aklımız ermezmiş bizim, öyle diyorlar. Senin adına konuşan ne çok insan var Tanrım, hiç dikkatini çekti mi? Yani çekmiştir mutlaka da. Tanrım ona iyi bak olur mu? Biliyorsun o ticaretten anlamaz. Kendisi mutlaka aksini iddia edecektir ama sen yine de onu ticari bi işte kullanma. İyi bir memurdur aslında. Masa başı bir iş verirsen mutlaka başarılı olacaktır. Özür dilerim Tanrım, işine karışıyor gibi oluyorum ama. Tanrım, o çok iyi bir insandı. Ve herhalde onu cennetine alacaksındır. Bu da benim onu bir daha göremeyeceğim anlamına geliyor. Çünkü ben deliyim ve cennete giremem herhalde. Çok uzattım biliyorum çok uzattım ama hemen bitiriyorum. Son olarak, kendimle ilgili bir şey sormak istiyorum. Belki kızacaksın ama sormak zorundayım.\nTanrım, ben şimdi ne yapacağım?',
      targetEmotion: 'Hüzün / Naiflik',
      difficulty: 'Orta',
      duration: '2.5dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCw9pMJSDsCkdOVITlRhHP9ZYf5VGOrdjuAaZ-EnFbb6zg-_yrOx3AXxUEEgDhx-EWN_sDGJ8wQXhGTJPRsVCLXTc0jkB_-EHVIVJcIGMommQE7IWQ1QaDB1ev3HJlvgh0AY4v-eEJxqrjvpcEFTqTmNJCGl8BLgY1FIG76M0N4z5p45I3QSK0Jbo0LHF1vhakNh0qzi9CLXYqosimEcZKGU-xjm_7gIu4BDMGM2pcw4ZtMP54oLpH2sUdSNTHgiHNpC1XxgKiXiiQ',
      aiScore: '93%',
    ),
    TriadModel(
      id: 'vladimir___estragon',
      name: 'Vladimir / Estragon',
      title: 'Vladimir / Estragon (Samuel Beckett)',
      author: 'Samuel Beckett',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu felsefi, sorgulayıcı ve absürt tiyatronun getirdiği varoluşsal ritme uygun, yer yer coşkulu yer yer alaycı bir üslup benimsemelidir.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu felsefi, sorgulayıcı ve absürt tiyatronun getirdiği varoluşsal ritme uygun, yer yer coşkulu yer yer alaycı bir üslup benimsemelidir.',
      script: 'Boş konuşmalarla zamanımızı harcamayalım!\nFırsat varken bir şeyler yapalım!\nHer gün birilerinin bize ihtiyacı olmuyor.\nAslında özellikle bize ihtiyaç duymuyorlar.\nBaşkaları da daha iyi olmasa bile, aynı derecede bizim yaptıklarımızı yapabilirlerdi.\nKulaklarımızda çınlayan şu yardım çığlıkları bütün insanlığa yöneltilmiş!\nAma burada, zamanın bu anında, istesek de istemesek de bütün insanlık biziz.\nÇok geç olmadan bundan yararlanalım!\nZalimce bir alın yazısının bize layık gördüğü iğrenç güruhu hakkıyla temsil edelim!\nNe dersin?\nKollarımızı kavuşturup yardım etmenin iyi ve kötü yanlarını hesaplarken cinsimize kötülük etmediğimiz doğru.\nKaplan hiç düşünmeden hemcinsinin yardımına koşar ya da çalılıkların kuytularına siner.\nAma sorun bu değil.\nSorun burada ne yaptığımız.\nVe cevabı bildiğimiz için mutluyuz.\nEvet, bu uçsuz bucaksız karmaşada kesin olan tek bir şey var.\nGodot\'nun gelmesini bekliyoruz.\nYa da geceniz çökmesini.\nBuluşacağımız yere saatinde geldik ve bu da sonu işte.\nAziz değiliz ama bu da sonu işte.\nAziz değiliz ama buluşacağımız yere saatinde geldik.\nKaç insan böyle bir şeyle övünebilir?',
      targetEmotion: 'Varoluşsal Kaygı / Coşku',
      difficulty: 'İleri',
      duration: '2dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBLNlgRkqU2euc_mW1Tz_YSZVjIcVrEc-TGOGDZCHay3GaNjLqUstcs-XngHIUjWGpHWuqRCeO98wjL_PT-Q0wsy-1ZNJIxa2ZGg5iUctOQ7HjAHo-gTs451PJySrjRqxWXDbHb8HYoZe2UA9EHLWASWNkEYABqjMDKM-X6_62lOi4hlFRTtL3Pe_IV0EmOYqMNoZh9tlAwrRKyN-3mR_lb3FANXUHHg1YY14JJpqTgtIxHrvPJ9Y2Jf8zVzw_Hd-HVULsM-EPYJ7I',
      aiScore: '91%',
    ),
    TriadModel(
      id: 'macbeth',
      name: 'Macbeth',
      title: 'Macbeth (Glamis Baronu)',
      author: 'William Shakespeare',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu güç tutkusu, vicdan azabı, korku ve suçluluk psikolojisi altındaki ağır, karanlık içsel hesaplaşmayı yansıtmalıdır.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu güç tutkusu, vicdan azabı, korku ve suçluluk psikolojisi altındaki ağır, karanlık içsel hesaplaşmayı yansıtmalıdır.',
      script: 'Yapmakla olup bitseydi bu iş,\nHemen yapardım, olup biterdi.\nDöktüğüm kanla akıp gitse her şey,\nBir vuruşta sonuna varılsa işin,\nBir anda bu dünyayı olsun kazanıversen,\nZaman denizinin bir kumsalı olan bu dünyayı,\nÖbür dünyayı gözden çıkarır insan.\nAma bu işlerin daha burada görülüyor hesabı.\nVerdiğimiz kanlı dersi alan\nGelip bize veriyor aldığı dersi.\nDoğruluğun şaşmaz eli bize sunuyor\nİçine zehir döktüğümüz kupayı.\nAdam burada, iki katlı güvenlikte:\nBir kere akrabası ve adamıyım:\nOna kötülük etmemem için iki zorlu sebep.\nSonra misafirim;\nDeğil kendim bıçaklamak,\nEl bıçağına karşı korumam gerek onu.\nÜstelik bu Duncan, ne iyi yürekli bir insan,\nVe ne bulunmaz bir kral.\nHer değeri ayrı bir İsrafil borusu olur\nLanet okumak için onu öldürene!\nAcımak yeni doğmuş bir child olur, çırılçıplak,\nKasırganın yelesine sarılmış,\nYa da bir melek, görülmez atlarına binmiş göklerin,\nVe gider dört bir yana haber verir\nBu yürekler acısı cinayeti,\nGöz yaşı savrulur esen yellerde.\nSebep yok onu öldürmem için,\nBeni mahmuzlayan tek şey, kendi yükselme hırsım;\nO da bir atlayış atlıyor ki atın üstüne\nÖbür tarafa düşüyor, eğerde duracak yerde.',
      targetEmotion: 'Korku / Vicdan Azabı / Hırs',
      difficulty: 'İleri',
      duration: '3.5dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAFmS7fSkntC4CZhAgojLUXznhsGc6uLPskAxfm5wcWtpBNjUi2qOAkSRBFzIUYu5sJqMC0F6ROdqmBU_ZlNUBVgQ9htIQ11k7nHlCeqWC8sEFZcRATueR78Sy0fGFcT8H5u8dKLj_ababZ-1ca5fSUwd0WYM7MPMHnRJ9Tf4wWndwoDgrbkpnO6ZmIF4k1kO-TUX2MB0QEBnZexCCW1NCYE9Q-5s_mGAaQ4ezooxgteLU3fgsI9sNBkISb53pD7gPZwsHJyBCbLhg',
      aiScore: '89%',
    ),
    TriadModel(
      id: 'hamlet',
      name: 'Hamlet',
      title: 'Hamlet (Danimarka Prensi)',
      author: 'William Shakespeare',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Dünya tiyatro tarihinin en ikonik monoloğunda oyuncu derin bir felsefi sorgulama, melankoli ve öfke patlamaları arasındaki gelgitleri aktarmalıdır.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Dünya tiyatro tarihinin en ikonik monoloğunda oyuncu derin bir felsefi sorgulama, melankoli ve öfke patlamaları arasındaki gelgitleri aktarmalıdır.',
      script: 'Olmak ya da olmamak, işte bütün mesele bu!\nDüşüncemizin katlanması mı güzel\nZalim oklarına kaderin yumruklarına, oklarına\nYoksa diretip bela denizlerine karşı\nDur, yeter demesi mi?\nÖlmek, uyumak sadece!\nDüşünün ki uyumakla yalnız\nBitebilir bütün acıları yüreğin,\nÇektiği bütün kahırlar insanoğlunun.\nUyumak, ama düş görebilirsin uykuda, o kötü.\nÇünkü, o ölüm uykularında\nSıyrıldığımız zaman yaşamak kaygısından\nNe düşler görebilir insan, düşünmeli bunu.\nBu düşüncedir felaketleri yaşanır yapan.\nYoksa kim dayanabilir zamanın kırbacına?\nZorbanın kahrına, gururunun çiğnenmesine\nSevgisinin kepaze edilmesine\nKanunların bu kadar yavaş\nYüzsüzlüğün bu kadar çabuk yürümesine\nKötülere kul olmasına iyi insanın\nBir bıçak saplayıp göğsüne kurtulmak varken?\nKim ister bütün bunlara katlanmak\nAğır bir hayatın altında inleyip terlemek\nÖlümden sonraki bir şeyden korkmasa\nO kimsenin gidip de dönmediği bilinmez dünya\nÜrkütmese yüreğini?\nBilmediğimiz belalara atılmaktansa\nÇektiklerine razı etmese insanları?\nBilinç böyle korkak ediyor hepimizi:\nDüşüncenin soluk ışığı bulandırıyor\nYürekten gelenin doğal rengini.\nVe nice büyük, yiğitçe atılışlar\nYollarını değiştirip bu yüzden\nBir iş, bir eylem olma gücünü yitiriyorlar.',
      targetEmotion: 'Varoluşsal Acı / Melankoli',
      difficulty: 'İleri',
      duration: '3dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBLNlgRkqU2euc_mW1Tz_YSZVjIcVrEc-TGOGDZCHay3GaNjLqUstcs-XngHIUjWGpHWuqRCeO98wjL_PT-Q0wsy-1ZNJIxa2ZGg5iUctOQ7HjAHo-gTs451PJySrjRqxWXDbHb8HYoZe2UA9EHLWASWNkEYABqjMDKM-X6_62lOi4hlFRTtL3Pe_IV0EmOYqMNoZh9tlAwrRKyN-3mR_lb3FANXUHHg1YY14JJpqTgtIxHrvPJ9Y2Jf8zVzw_Hd-HVULsM-EPYJ7I',
      aiScore: '96%',
    ),
    TriadModel(
      id: 'popriscin',
      name: 'Poprişçin',
      title: 'Poprişçin (Nikolay Gogol)',
      author: 'Nikolay Gogol',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Şizofrenik kopuşlar barındıran bu metinde oyuncu dramatik hezeyanlar, yoğun hüzün, çocuksu bir sığınma arzusu ve aniden gelişen absürt komedi tonunu yansıtmalıdır.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Şizofrenik kopuşlar barındıran bu metinde oyuncu dramatik hezeyanlar, yoğun hüzün, çocuksu bir sığınma arzusu ve aniden gelişen absürt komedi tonunu yansıtmalıdır.',
      script: 'Artık dayanacak halim kalmadı.\nTanrım! Neler yapıyorlar bu adamlar bana!..\nDuymuyor, görmüyor, dinlemek istemiyorlar beni.\nNe yaptım onlara?..\nNeden eziyet ediyor, benim gibi zavallıdan ne istiyorlar, ne verebilirim onlara?\nHiç bir şeyim yok.\nBittim artık,\ndayanamayacağım işkencelerinden.\nBaşım ateşler içinde yanıyor,\nher şey dönüyor gözlerimin önünde.\nYok mu beni buradan kurtaracak bir?..\nBir troika; yıldırım gibi atlar koşulu troika gelsin!..\nBabayiğit bir arabacı sürsün aslanlarını, şıngır şıngır ötsün çıngıraklar.\nUçursunlar beni bu cehennem dünyasından.\nUzağa, çok uzağa.\nHiçbir şey göremeyeceğim, duyamayacağım bir yere.\nİşte gökteki bulutlar kabarıp dönmeğe başladı önümde,\nuzaktan bir yıldız parladı.\nOrmanların loşluğu, ayın donuk ışığı gözümün önünde kaydıkça kayıyor.\nAyaklarımın altında mavi bir sis şeridi yayıldı.\nHavada gerilen bir telin vınlamasını duyuyorum.\nBir yanımda deniz, öbür yanımda İtalya.\nİşte Rus köylerinin karanlık evleri belirdi.\nOracıkta bir karaltı halinde gördüğüm küçük ev benim evim mi yoksa?..\nPencerenin önünde oturan kadın anam olmasın?..\nAnacığım, kurtar zavallı oğlunu!\nAğrıyan başına bir damla gözyaşı akıt, ne olur!\nGör, nasıl hırpalıyorlar evladını, bağrına bas bedbaht öksüzünü.\nYok onun yeri bu dünyada artık, insanlar aleminden attılar onu...\nBari sen acı hasta oğluna anacığım!\n(Burada kısa bir boşluk, zihinsel kopuş.)\nŞey...\nHaberiniz var mı?..\nCezayir Beyinin burnunun altında kocaman bir ben varmış!..',
      targetEmotion: 'Hezeyan / Çaresizlik / Şaşkınlık',
      difficulty: 'İleri',
      duration: '4dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBLNlgRkqU2euc_mW1Tz_YSZVjIcVrEc-TGOGDZCHay3GaNjLqUstcs-XngHIUjWGpHWuqRCeO98wjL_PT-Q0wsy-1ZNJIxa2ZGg5iUctOQ7HjAHo-gTs451PJySrjRqxWXDbHb8HYoZe2UA9EHLWASWNkEYABqjMDKM-X6_62lOi4hlFRTtL3Pe_IV0EmOYqMNoZh9tlAwrRKyN-3mR_lb3FANXUHHg1YY14JJpqTgtIxHrvPJ9Y2Jf8zVzw_Hd-HVULsM-EPYJ7I',
      aiScore: '94%',
    ),
    TriadModel(
      id: 'yalniz_kadin',
      name: 'Yalnız Kadın',
      title: 'Yalnız Kadın (Dario Fo & Franca Rame)',
      author: 'Dario Fo & Franca Rame',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu histerik, baskı altında yaşayan, öfkeli ama dış dünyaya karşı neşeli görünmeye çalışan kadının trajikomik durumunu hızlı tempo değişimleriyle aktarmalıdır.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu histerik, baskı altında yaşayan, öfkeli ama dış dünyaya karşı neşeli görünmeye çalışan kadının trajikomik durumunu hızlı tempo değişimleriyle aktarmalıdır.',
      script: '(Telefon çalar)\nAh, kocam olacak…\nhep bu saatlerde arar beni…\nözür dilerim bir dakika…\nAlo?\nEvet…\nNe?\nNeee?\nhastir bok…\n(Telefonu kapar)\nUtanmıştır.\nAh çok afedersiniz…\nben aslında hiç kötü söz kullanmam…\nama bazen kaşınıyorlar…\nYok… yok… kocam değildi…\nkim olduğunu bilmiyorum…\nDomuzun teki…\ngünde iki üç… bin kere…\nÖylesine iğrenç sözler söyler ki…\nNereden biliyorum olur mu?\nBaktım sözlüğe, bulamadım…\nHasta mı?\nBaksanıza bende… evde bir hasta var…\n(Telefon yeniden çalar)\nBak gene o…\nDinle domuz…\nSeni uyarıyorum…\nCiao…\nKocam…\nSeninle ilgisi yok canım…\nkorkunç kötü sözler söylüyor…\nSana kızgın…\nSana borcun varmış…\n(Ev içi yalanlar hızlanır)\nEvet… evet… evet…\nKontrollü…\nKim sinirli…\nÇok çok neşeliyim…\n(bağırır)\nAldo çok neşeliyim!\nÇok neşeliyiiiim…\n(telefonu kapatır, çığlık)\nGördünüz mü?\nYalan söylemek zorunda kaldım…\no domuzun telefon ettiğini söyleyemem…\nZaten eve kilitliyor… hapisim…\n(üşütücü sakinlik)\nO anda röntgenciyi görür…\nYakaladım seni!\nAyy…\nGöğsümü yaktım…\nGörüyorsunuz değil mi…',
      targetEmotion: 'Histeri / Öfke / Trajikomik',
      difficulty: 'İleri',
      duration: '3dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCw9pMJSDsCkdOVITlRhHP9ZYf5VGOrdjuAaZ-EnFbb6zg-_yrOx3AXxUEEgDhx-EWN_sDGJ8wQXhGTJPRsVCLXTc0jkB_-EHVIVJcIGMommQE7IWQ1QaDB1ev3HJlvgh0AY4v-eEJxqrjvpcEFTqTmNJCGl8BLgY1FIG76M0N4z5p45I3QSK0Jbo0LHF1vhakNh0qzi9CLXYqosimEcZKGU-xjm_7gIu4BDMGM2pcw4ZtMP54oLpH2sUdSNTHgiHNpC1XxgKiXiiQ',
      aiScore: '92%',
    ),
    TriadModel(
      id: 'nina',
      name: 'Nina',
      title: 'Nina (Antov Çehov)',
      author: 'Antov Çehov',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Karakterin geçmişteki kırgınlıkları, başarısızlık hissi ve monoloğun sonuna doğru yükselen umut, sabır ve oyuncu olma bilinci hassas bir duygu tonuyla oynanmalıdır.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Karakterin geçmişteki kırgınlıkları, başarısızlık hissi ve monoloğun sonuna doğru yükselen umut, sabır ve oyuncu olma bilinci hassas bir duygu tonuyla oynanmalıdır.',
      script: 'Neden bastığım toprakları öptüğünü söyledin bana?\nBeni öldürmek gerek.\nÖyle yorgunum ki!\nDinlenebilsem, birazcık dinlenebilsem!..\nBir martıyım ben...\nYok, değil, aktristim.\nAh, evet!\nO da burada demek!..\nEh, iyi..\nNe yapalım...\nEvet...\nTiyatroya inanmıyor, hayallerimle alay ediyordu...\nBöylece ben de inancımı yitirdim yavaş yavaş, hevesim kalmadı...\nSonra aşkın getirdiği sorunlar, kıskançlıklar, yavrum için duyduğum sürekli korku...\nUfaldım, zavallılaştım, boş bir kalıp gibi oynamaya başladım sahnede...\nEllerimi nereye koyacağımı bilemiyor, ayakta düzgün durmayı beceremiyor, sesimi denetleyemiyordum...\nİnsanın çok berbat oynadığını hissetmesi ne korkunç şeydir bilemezsiniz!\nBir martıyım ben.\nYok, değil.\nAnımsıyor musunuz, bir martı vurmuştunuz.\nGünün birinde bir adam geliyor, görüyor onu ve yapacak başka bir işi olmadığından kıyıyor ona...\nKüçük bir hikâye konusu...\nYok, bu da değildi söylemek istediğim...\nNe diyordum?..\nSahneden söz ediyordum, evet.\nŞimdi öyle değilim artık...\nŞimdi gerçek bir aktristim,\nzevk duyarak, coşkuyla oynuyorum;\nkendimden geçiyorum sahnede ve çok güzel olduğumu hissediyorum...\nBurada olduğum şu günlerde de yürüyorum hep, yürüyor ve düşünüyorum...\nİçimdeki bir gücün gelişip büyüdüğünü hissediyorum git gide...\nKostya, yazmışız, ya da sahnede oynamışız, fark etmez,\nanlıyorum ki bizim bu işlerde başta gelen şey, parıltı, şöhret filan gibi benim hayal ettiğim o şeyler değil, sabredebilme yeteneğidir...\nKaderine katlanmasını bil ve inançlı ol..\nİnanıyorum ben ve o kadar çok acı çekmiyorum şimdi...\nBir görevim, bir amacım olduğunu düşündüğümde, hayattan korkmuyorum...',
      targetEmotion: 'Kırgınlık / Teslimiyet / Umut',
      difficulty: 'İleri',
      duration: '3.5dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCw9pMJSDsCkdOVITlRhHP9ZYf5VGOrdjuAaZ-EnFbb6zg-_yrOx3AXxUEEgDhx-EWN_sDGJ8wQXhGTJPRsVCLXTc0jkB_-EHVIVJcIGMommQE7IWQ1QaDB1ev3HJlvgh0AY4v-eEJxqrjvpcEFTqTmNJCGl8BLgY1FIG76M0N4z5p45I3QSK0Jbo0LHF1vhakNh0qzi9CLXYqosimEcZKGU-xjm_7gIu4BDMGM2pcw4ZtMP54oLpH2sUdSNTHgiHNpC1XxgKiXiiQ',
      aiScore: '90%',
    ),
    TriadModel(
      id: 'nilufer',
      name: 'Nilüfer',
      title: 'Nilüfer (Adalet Ağaoğlu)',
      author: 'Adalet Ağaoğlu',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu başlangıçtaki kibirli ve iddialı tutum ile monoloğun sonundaki ihanete uğramışlık ve şaşkınlık hissini keskin bir geçişle vermelidir.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Oyuncu başlangıçtaki kibirli ve iddialı tutum ile monoloğun sonundaki ihanete uğramışlık ve şaşkınlık hissini keskin bir geçişle vermelidir.',
      script: 'Benim adım Nilüfer.\nNasıl tanıdınız beni o kadar mektup arasında?\nNasıl Fer’li kadınlar?\nNe tesadüf, şimdi de hayatınıza bir Nilüfer giriyor…\nOnları nasıl unutamadınızsa, beni de unutamayacaksınız.\nPek yakında olağanüstü bir şey olacak…\nSade siz değil, bütün Türkiye beni unutamayacak…\nİsterseniz başından anlatayım?\nBir arkadaş davetinde tanıştık.\nAdı Sekban’mış.\nNonşolant bir hali vardı.\nPipo içiyor ve alçak sesle konuşuyordu.\nDerhal yıldırımla vurulmak derler ya, öyle vuruldum.\nDüşünün bir kere, erkeklerin çoğu çayı şekerli ya da az şekerli içer, bu kırklama içiyordu.\nİdealimdeki erkek…\nSonrası, deliler gibi seviştik.\nAma gel gör ki, ailelerimiz bizi birbirimize vermiyor.\nBir çeşit Romeo Jüliyet durumu.\nRomeo Jüliyet canım.\nBiz kaçmaya karar verdik.\nSekban Mobil Oil’de çalışıyor.\nTahsili yok ama, İngilizcesi iyi.\nAyda 2500 lira alıyor.\nDün tam hazırlanıyorum, kapı.\nBir buket menekşe, en sevdiğim çiçek menekşedir.\nÜzerinde kartı vardı.\n“Affet beni Nilüfer, şirket beni Güney Afrika’ya gönderiyor, bu işi burada keselim, daha iyi.”\nSonsuz sevgiler, imza…\nTaksiye atlıyorum hemen, ver elini Ayazpaşa.\nBenim için ağladığını söyleyen o ahlaksız serseri,\nsarılar giymiş bir kızla el ele,\nbir de bakıyorum Müjgân…\nEn iyi arkadaşım Müjgân.',
      targetEmotion: 'İhanet / Hayal Kırıklığı',
      difficulty: 'Orta',
      duration: '2.5dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCw9pMJSDsCkdOVITlRhHP9ZYf5VGOrdjuAaZ-EnFbb6zg-_yrOx3AXxUEEgDhx-EWN_sDGJ8wQXhGTJPRsVCLXTc0jkB_-EHVIVJcIGMommQE7IWQ1QaDB1ev3HJlvgh0AY4v-eEJxqrjvpcEFTqTmNJCGl8BLgY1FIG76M0N4z5p45I3QSK0Jbo0LHF1vhakNh0qzi9CLXYqosimEcZKGU-xjm_7gIu4BDMGM2pcw4ZtMP54oLpH2sUdSNTHgiHNpC1XxgKiXiiQ',
      aiScore: '88%',
    ),
    TriadModel(
      id: 'harpagon',
      name: 'Harpagon',
      title: 'Harpagon (Molière)',
      author: 'Molière',
      desc: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Klasik komedinin en önemli örneklerinden olan bu tiratta oyuncu yüksek tempo, panik, nefes nefese bir öfke ve aşırı mal hırsının getirdiği gülünç çaresizliği sahnelemelidir.',
      rules: 'Gemma modelinin analiz yaparken kullandığı temel kurallar. Klasik komedinin en önemli örneklerinden olan bu tiratta oyuncu yüksek tempo, panik, nefes nefese bir öfke ve aşırı mal hırsının getirdiği gülünç çaresizliği sahnelemelidir.',
      script: 'Yetişin! Hırsız var!\nYakalayın!\nAdam öldürüyorlar!\nCan kurtaran yok mu?\nHak, adalet nerede?\nAllah yok mu?\nVurdular! Canımı aldılar!\nGırtlağımı kestiler!\nParamı çaldılar, paramı!\nKim aldı, kim?\nNe oldu? Nerede?\nNereye saklandı?\nNe yapayım? Nasıl bulayım?\nNereye koşayım? Nereye koşmayayım?\nŞurada mı acaba? Burada mı yoksa?\nKim o? Dur! Yakaladım.\nVer paralarımı haydut!\nEyvah! Benmişim yakaladığım.\nNeredeyim, bilmiyorum ki!\nBen kimim? Ne yapıyorum?\nBilmiyorum.\nOldu bana olanlar!\nParam!\nZavallı paracığım!\nCanım, sevgilim benim!\nAldılar elimden seni!\nSen olmayınca ben neye sığınırım artık?\nNe ile avunur; ne ile sevinirim?\nHer şey bitti benim için!\nDünyada yapacak işim kalmadı benim!\nSensiz ne yaparım, nasıl yaşarım?\nOlacak şey mi?\nYaptılar bana yapacaklarını!\nDayanamam bu acıya!\nÖlüyorum; öldüm, gömdüler beni!\nDiriltmek isteyen yok mu beni?\nVersin paracıklarımı geri!\nYa da kimin aldığını söylesin!\nNe var? Ne diyorsunuz?\nKimse yokmuş.\nBu işi yapan bir hayli pusuda beklemiş olmalı…\nHadi durma git!\nGit, adalete başvur!\nHepsinin parmağı var bu hırsızlıkta!\nHadi gelsin jandarmalar!\nAstıracağım bütün dünyayı!',
      targetEmotion: 'Panik / Öfke / Çaresizlik',
      difficulty: 'İleri',
      duration: '2.5dk',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAFmS7fSkntC4CZhAgojLUXznhsGc6uLPskAxfm5wcWtpBNjUi2qOAkSRBFzIUYu5sJqMC0F6ROdqmBU_ZlNUBVgQ9htIQ11k7nHlCeqWC8sEFZcRATueR78Sy0fGFcT8H5u8dKLj_ababZ-1ca5fSUwd0WYM7MPMHnRJ9Tf4wWndwoDgrbkpnO6ZmIF4k1kO-TUX2MB0QEBnZexCCW1NCYE9Q-5s_mGAaQ4ezooxgteLU3fgsI9sNBkISb53pD7gPZwsHJyBCbLhg',
      aiScore: '95%',
    )
];

  // Save User Profile Information
  Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String name,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Retrieve User Profile Information
  Future<DocumentSnapshot> getUserProfile(String uid) async {
    return await _db.collection('users').doc(uid).get();
  }

  // Stream User Profile Information (for live updates like home screen welcome greeting)
  Stream<DocumentSnapshot> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // Save Performance Data
  Future<String> savePerformance({
    required String uid,
    required String title,
    required String genre,
    required String videoUrl,
    required int score,
    required String duration,
  }) async {
    final docRef = _db.collection('users').doc(uid).collection('performances').doc();
    
    // Generate detailed mock analysis metrics
    final emotions = {
      'Mutlu': 0.5 + (score * 0.004),
      'Endişe': 0.8 - (score * 0.007),
      'Öfke': 0.6 - (score * 0.005),
      'Nötr': 0.4 + (score * 0.002),
      'Üzgün': 0.3 - (score * 0.003),
    };
    
    // Ensure values remain between 0 and 1
    emotions.updateAll((key, value) => value.clamp(0.0, 1.0));

    final suggestions = [
      {
        'title': 'Durgunluk Analizi',
        'desc': 'Sahnede verdiğin duraksama temposu genel akışla dengeli, ancak bazı yerlerde 1.2 saniye hızlandırabilirsin.',
        'icon': 'analytics_outlined',
      },
      {
        'title': 'Duygusal Tutarlılık',
        'desc': 'Sözlerin tonuyla yüz ifadelerin arasındaki uyum skoru oldukça yüksek. Beden dilini de entegre etmeye çalış.',
        'icon': 'psychology_outlined',
      }
    ];

    final performance = PerformanceModel(
      id: docRef.id,
      title: title,
      genre: genre,
      videoUrl: videoUrl,
      score: score,
      duration: duration,
      date: DateTime.now(),
      wer: double.parse((2.0 + (100 - score) * 0.15).toStringAsFixed(1)),
      tempo: 110 + (score % 30),
      emotions: emotions,
      suggestions: suggestions,
    );

    await docRef.set(performance.toMap());
    return docRef.id;
  }

  // Get Stream of Performances
  Stream<List<PerformanceModel>> streamPerformances(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('performances')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PerformanceModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Retrieve WebSocket/API Server host from configs/server document in Firestore
  Future<String> getServerHost() async {
    try {
      final doc = await _db.collection('configs').doc('server').get();
      if (doc.exists) {
        final host = doc.data()?['host'];
        if (host != null && host.toString().trim().isNotEmpty) {
          var cleanHost = host.toString().trim();
          // Clean prefixes to ensure only host remains
          cleanHost = cleanHost.replaceAll(RegExp(r'^wss?://'), '');
          cleanHost = cleanHost.replaceAll(RegExp(r'^https?://'), '');
          if (cleanHost.endsWith('/')) {
            cleanHost = cleanHost.substring(0, cleanHost.length - 1);
          }
          return cleanHost;
        }
      }
    } catch (e) {
      print("Error fetching server host from Firestore: $e");
    }
    // Default fallback
    return 'altered-medieval-sales-packed.trycloudflare.com';
  }
}
