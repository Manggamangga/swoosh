# Flutter over React Native and PWA

Swoosh is a mobile-first personal finance app used daily on Android and iOS. We chose Flutter/Dart over React Native (which would reuse Sean's React/TS skills) and over a React PWA (which would use Shadcn/Tailwind exactly but deliver a weaker native iPhone experience). Flutter was picked for superior native UI feel on both platforms; the team accepts learning Dart and using Riverpod instead of Zustand/TanStack Query.

**Considered options:** Expo (React Native) + TypeScript; React PWA (Vite + Shadcn); Flutter/Dart.

**Consequences:** No Shadcn/Tailwind — design system is custom Material 3 tokens. State management is Riverpod, not Zustand.
