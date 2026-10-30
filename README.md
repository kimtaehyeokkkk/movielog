# movielog

UMC 11기 Flutter 워크북 MovieLog 앱입니다. 영화 정보는 TMDB API에서 가져옵니다.

## 실행 전 준비: `.env`

`pubspec.yaml`이 `.env`를 asset으로 등록하고 앱 시작 시 `dotenv.load`로 읽기 때문에,
**새로 clone한 뒤에는 `.env`를 먼저 만들어야 합니다.** `.env`는 개인 Token이 들어가므로 Git에 올리지 않습니다.

1. 예시 파일을 복사합니다.

   ```bash
   cp .env.example .env
   ```

   Windows PowerShell에서는 `Copy-Item .env.example .env`

2. `.env`의 `TMDB_ACCESS_TOKEN=` 뒤에 TMDB **API Read Access Token**(긴 문자열)을 넣습니다.
   Token은 TMDB 설정 → API에서 발급합니다.

3. 실행합니다.

   ```bash
   flutter pub get
   flutter run
   ```

테스트(`flutter test`)는 실제 TMDB를 호출하지 않으므로 Token 값이 비어 있어도 됩니다.
