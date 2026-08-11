# Prism Fleet Operations v1.3

A production-ready, multi-user fleet operations and monitoring system built with Next.js, Supabase, and Wialon integration.

## Features

- **Authentication**: Multi-user login with Supabase Auth
- **Dashboard**: Real-time fleet overview
- **Persistent State**: All operational data stored in Supabase PostgreSQL
- **Multi-User Support**: Different employees see the same operational state
- **Wialon Integration**: Live truck tracking and telemetry

## Quick Start

### Prerequisites

1. Node.js 18+ installed
2. A Supabase project with the database schema applied
3. Wialon SID for telemetry integration

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd prism-1.3
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env.local` file in the root directory:
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
WIALON_SID=your_wialon_sid
```

4. Run the development server:
```bash
npm run dev
```

5. Open [http://localhost:3000](http://localhost:3000) in your browser

## Database Setup

Run the SQL script `fleet-schema.sql` in your Supabase SQL Editor to create all required tables, policies, and functions.

## Deployment

### Deploy to Vercel

1. Push your code to GitHub
2. Go to [vercel.com](https://vercel.com)
3. Import your repository
4. Add your environment variables in the Vercel dashboard
5. Deploy!

## Project Structure

```
src/
├── app/                  # Next.js App Router pages
│   ├── login/           # Login page
│   ├── dashboard/       # Main dashboard
│   └── layout.tsx       # Root layout
├── components/          # Reusable React components
├── hooks/              # Custom React hooks (useAuth, etc.)
├── lib/                # Core utilities
│   └── supabase/       # Supabase client configurations
└── types/              # TypeScript type definitions
```

## Architecture

- **Frontend**: Next.js 14 with TypeScript and Tailwind CSS
- **Backend**: Supabase (PostgreSQL + Auth + RLS)
- **Live Telemetry**: Wialon API
- **Hosting**: Vercel
- **Authentication**: Supabase Auth with Row Level Security

## License

See LICENSE file
