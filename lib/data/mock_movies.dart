import 'package:movielog/models/movie.dart';

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genres: ['드라마', '로맨스'],
    year: 2024,
    runtimeMinutes: 124,
    rating: 4.5,
    ratingCount: 1245,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    synopsis:
        '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 작은 천문대에서 만나게 됩니다. '
        '매일 밤 별을 관측하며 서로의 상처를 치유하고, 잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.',
    tags: ['로맨스', '드라마', '감동적인'],
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genres: ['SF'],
    year: 2024,
    runtimeMinutes: 138,
    rating: 4.2,
    ratingCount: 982,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    synopsis: '시놉시스 2',
    tags: ['SF', '우주', '미스터리'],
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genres: ['애니메이션'],
    year: 2022,
    runtimeMinutes: 102,
    rating: 4.9,
    ratingCount: 2310,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    synopsis: '시놉시스 3',
    tags: ['애니메이션', '판타지', '따뜻한'],
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genres: ['스릴러'],
    year: 2024,
    runtimeMinutes: 115,
    rating: 3.8,
    ratingCount: 654,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    synopsis: '시놉시스 4',
    tags: ['스릴러', '범죄', '긴장감'],
  ),
  Movie(
    id: 5,
    title: '봄날의 커피',
    genres: ['로맨스'],
    year: 2021,
    runtimeMinutes: 108,
    rating: 4.5,
    ratingCount: 1102,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    synopsis: '시놉시스 5',
    tags: ['로맨스', '일상', '잔잔한'],
  ),
  Movie(
    id: 6,
    title: '스파이 코드',
    genres: ['액션'],
    year: 2023,
    runtimeMinutes: 131,
    rating: 4.6,
    ratingCount: 1876,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    synopsis: '시놉시스 6',
    tags: ['액션', '첩보', '코미디'],
  ),
];

const genreOptions = [
  '드라마',
  'SF',
  '애니메이션',
  '스릴러',
  '로맨스',
  '액션',
  '코미디',
  '판타지',
  '다큐멘터리',
];

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}

List<Movie> get popularMovies {
  final sorted = [...movies];
  sorted.sort((a, b) {
    final byRating = b.rating.compareTo(a.rating);
    if (byRating != 0) return byRating;
    return a.id.compareTo(b.id);
  });
  return sorted;
}