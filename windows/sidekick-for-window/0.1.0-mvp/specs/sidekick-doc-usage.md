# sidekick-doc 사용법

PowerShell 실행 정책 때문에 직접 `.ps1`을 실행하지 말고, 아래 배치 파일을 사용한다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat
```

## 1. 문서 연결

처음 한 번만 실행한다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat link "C:\Users\NeoSol\Desktop\문서.hwp"
```

## 2. 수동 스냅샷

현재 문서를 vault에 저장한다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat snapshot "C:\Users\NeoSol\Desktop\문서.hwp" -Label "예산수정전" -Summary "예산표 수정 전 백업"
```

## 3. 덮어쓰기 커밋

수정본을 원본 위치에 덮어쓰기 전에 기존 원본을 자동 스냅샷으로 저장한다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat commit "C:\Users\NeoSol\Desktop\문서.hwp" -Candidate "C:\Users\NeoSol\Desktop\수정본.hwp" -Label "예산수정" -Summary "드론 예산 재분류"
```

## 4. 버전 목록 확인

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat list "C:\Users\NeoSol\Desktop\문서.hwp"
```

## 5. 연결 문서 목록 확인

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat docs
```

## 6. 이전 버전 복구

복구 전 현재 파일을 보호 스냅샷으로 저장한 뒤, 지정 버전으로 원본을 덮어쓴다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat restore "C:\Users\NeoSol\Desktop\문서.hwp" -Version 3
```

## 7. 버전 보호/해제

보호된 버전은 자동 정리 대상에서 제외된다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat protect "C:\Users\NeoSol\Desktop\문서.hwp" -Version 3
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat unprotect "C:\Users\NeoSol\Desktop\문서.hwp" -Version 3
```

## 8. 제출본 내보내기

현재 문서를 vault의 `exports`에 보관하고, 지정 폴더에도 복사한다. 내보낸 버전은 자동 보호된다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat export "C:\Users\NeoSol\Desktop\문서.hwp" -ExportPath "C:\Users\NeoSol\Desktop" -Label "제출본" -Summary "K-에듀파인 제출용"
```

## 9. Supabase용 메타데이터 내보내기

파일 원본은 업로드하지 않고, 문서/버전/로그용 메타데이터 JSON만 만든다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat meta "C:\Users\NeoSol\Desktop\문서.hwp"
```

## 10. 상태 확인

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat status "C:\Users\NeoSol\Desktop\문서.hwp"
```

## 11. 오래된 버전 정리

최근 10개와 보호 버전은 남긴다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\sidekick-doc.bat cleanup "C:\Users\NeoSol\Desktop\문서.hwp" -KeepRecent 10
```

## 12. rhwp 우선 점검

한글 프로그램을 열지 않고 HWP/HWPX를 먼저 읽어 검색, 정보 확인, 단순 치환을 시도한다.

```bat
C:\Users\NeoSol\Desktop\sidekick\tools\rhwp-inspect.bat "C:\Users\NeoSol\Desktop\문서.hwp"
C:\Users\NeoSol\Desktop\sidekick\tools\rhwp-inspect.bat "C:\Users\NeoSol\Desktop\문서.hwp" --search "이용선"
C:\Users\NeoSol\Desktop\sidekick\tools\rhwp-inspect.bat "C:\Users\NeoSol\Desktop\문서.hwp" --replace "이성진" --with "이용선" --out "C:\Users\NeoSol\Desktop\문서_수정본.hwp"
```

원칙: 검색/단순 치환/문서 정보 확인은 `rhwp`로 먼저 처리하고, 복잡한 표 편집이나 최종 육안 검토가 필요할 때만 한글 자동화를 사용한다.
