import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';

export default async function DashboardPage() {
  const supabase = await createClient();
  
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    redirect('/login');
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="mt-2 text-gray-600">Welcome, {user.email}</p>
        
        <div className="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <div className="bg-white overflow-hidden shadow rounded-lg p-5">
            <dt className="text-sm font-medium text-gray-500 truncate">Active Trucks</dt>
            <dd className="mt-1 text-3xl font-semibold text-gray-900">--</dd>
          </div>
          
          <div className="bg-white overflow-hidden shadow rounded-lg p-5">
            <dt className="text-sm font-medium text-gray-500 truncate">Active Runs</dt>
            <dd className="mt-1 text-3xl font-semibold text-gray-900">--</dd>
          </div>
          
          <div className="bg-white overflow-hidden shadow rounded-lg p-5">
            <dt className="text-sm font-medium text-gray-500 truncate">Queued</dt>
            <dd className="mt-1 text-3xl font-semibold text-gray-900">--</dd>
          </div>
          
          <div className="bg-white overflow-hidden shadow rounded-lg p-5">
            <dt className="text-sm font-medium text-gray-500 truncate">Completed Today</dt>
            <dd className="mt-1 text-3xl font-semibold text-gray-900">--</dd>
          </div>
        </div>
      </div>
    </div>
  );
}
