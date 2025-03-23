# 퀴즈 RPG: 지식의 모험

퀴즈 RPG: 지식의 모험은 퀴즈를 풀면서 경험치를 얻고 레벨업하며 다양한 아이템과 업적을 수집하는 교육적인 RPG 게임입니다.

## 주요 특징

- **다양한 퀴즈 카테고리**: 일반 지식, 수학, 과학, 지리, 프로그래밍, 역사 등 다양한 주제의 퀴즈
- **RPG 요소**: 레벨 시스템, 경험치, 아이템 사용, 지역 해금 등 RPG 요소 포함
- **업적 시스템**: 다양한 도전 과제를 완료하고 보상 획득
- **일일 퀘스트**: 매일 새로운 퀘스트로 보상 획득
- **아이템 시스템**: 다양한 아이템으로 게임 플레이 향상

## 게임 데이터 구조

프로젝트는 다음과 같은 데이터 파일을 포함합니다:

- `assets/data/quizzes.json`: 퀴즈 문제 데이터
- `assets/data/items.json`: 게임 내 아이템 데이터
- `assets/data/levels.json`: 레벨 시스템 데이터
- `assets/data/achievements.json`: 업적 시스템 데이터
- `assets/data/daily_quests.json`: 일일 퀘스트 데이터
- `assets/data/regions.json`: 게임 지역 데이터
- `assets/data/game_settings.json`: 게임 설정 데이터

## 폴더 구조

```
assets/
├── data/         # 게임 데이터 JSON 파일
└── images/       # 게임 이미지 에셋
    ├── items/        # 아이템 이미지
    ├── achievements/ # 업적 이미지
    ├── quests/       # 퀘스트 이미지
    ├── regions/      # 지역 배경 이미지
    ├── ui/           # UI 요소 이미지
    └── characters/   # 캐릭터 이미지
```

## 시작하기

1. Flutter 개발 환경 설정
2. 프로젝트 클론
3. 의존성 설치: `flutter pub get`
4. 앱 실행: `flutter run`

## 개발 환경

- Flutter 3.x
- Dart 3.x

## 기술 스택

- Flutter: UI 프레임워크
- Provider: 상태 관리
- Shared Preferences: 로컬 데이터 저장
- AudioPlayers: 소리 효과 및 배경 음악
