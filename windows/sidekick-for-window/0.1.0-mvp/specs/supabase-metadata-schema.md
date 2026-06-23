# Supabase 메타데이터 스키마 초안

문서 파일 원본은 업로드하지 않고, 문서 관리 기록만 저장한다.

## tables

### documents

문서 단위의 기본 정보.

```sql
create table documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  original_file_name text not null,
  local_path text not null,
  vault_path text not null,
  file_ext text not null,
  status text not null default 'active',
  current_version integer not null default 0,
  last_summary text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### document_versions

수정 전 스냅샷과 제출본 기록.

```sql
create table document_versions (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  version_no integer not null,
  label text not null,
  local_version_path text not null,
  change_summary text,
  is_protected boolean not null default false,
  is_export boolean not null default false,
  file_size_bytes bigint,
  created_at timestamptz not null default now(),
  unique(document_id, version_no)
);
```

### document_events

작업 로그. Codex/Sidekick이 어떤 작업을 했는지 남긴다.

```sql
create table document_events (
  id uuid primary key default gen_random_uuid(),
  document_id uuid references documents(id) on delete cascade,
  version_id uuid references document_versions(id) on delete set null,
  event_type text not null,
  message text not null,
  actor text not null default 'sidekick',
  created_at timestamptz not null default now()
);
```

### document_checklists

문서 유형별 체크리스트 적용 기록.

```sql
create table document_checklists (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  checklist_name text not null,
  item_key text not null,
  item_label text not null,
  checked boolean not null default false,
  note text,
  updated_at timestamptz not null default now(),
  unique(document_id, checklist_name, item_key)
);
```

## 저장하지 않을 것

- HWP/HWPX/DOCX/PDF 파일 본문
- 학생 개인정보
- 공문 원문 전체 텍스트
- 비밀번호, API 키, 인증 토큰

## 동기화 방식

- 로컬 작업이 우선이다.
- 인터넷이 없으면 로컬 `history.md`와 JSON 로그에 먼저 기록한다.
- 인터넷이 복구되면 메타데이터만 Supabase로 동기화한다.
- Supabase 동기화 실패가 문서 저장 실패로 이어지면 안 된다.

## 상태값 예시

`documents.status`

- `active`: 작업 중
- `submitted`: 제출 완료
- `archived`: 보관
- `deleted`: 로컬 삭제 기록만 남김

`document_events.event_type`

- `linked`
- `snapshot_created`
- `edited`
- `verified`
- `exported`
- `restored`
- `cleanup`
- `sync_failed`
