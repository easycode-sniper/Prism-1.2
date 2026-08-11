export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          email: string;
          display_name: string | null;
          role: 'admin' | 'operator' | 'viewer';
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          email: string;
          display_name?: string | null;
          role?: 'admin' | 'operator' | 'viewer';
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          email?: string;
          display_name?: string | null;
          role?: 'admin' | 'operator' | 'viewer';
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
      };
      trucks: {
        Row: {
          id: string;
          truck_number: string;
          wialon_unit_id: number | null;
          license_plate: string | null;
          capacity_tons: number | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      drivers: {
        Row: {
          id: string;
          name: string;
          phone: string | null;
          license_number: string | null;
          rating: number | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      sites: {
        Row: {
          id: string;
          name: string;
          site_type: 'factory' | 'construction' | 'gas_station' | 'other';
          latitude: number;
          longitude: number;
          address: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      geofences: {
        Row: {
          id: string;
          name: string;
          polygon: any;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      dispatches: {
        Row: {
          id: string;
          dispatch_number: string;
          truck_id: string;
          driver_id: string | null;
          origin_site_id: string;
          destination_site_id: string;
          status: 'queued' | 'active' | 'completed' | 'cancelled';
          dispatched_by: string;
          dispatched_at: string | null;
          arrived_at: string | null;
          completed_at: string | null;
          created_at: string;
          updated_at: string;
        };
      };
      run_history: {
        Row: {
          id: string;
          dispatch_id: string;
          truck_id: string;
          driver_id: string | null;
          origin_site_id: string;
          destination_site_id: string;
          started_at: string;
          completed_at: string | null;
          distance_km: number | null;
          duration_minutes: number | null;
          created_at: string;
        };
      };
      dispatch_events: {
        Row: {
          id: string;
          dispatch_id: string;
          event_type: string;
          event_data: any | null;
          created_by: string | null;
          created_at: string;
        };
      };
      notifications: {
        Row: {
          id: string;
          notification_type: string;
          title: string;
          message: string;
          severity: 'info' | 'warning' | 'error' | 'success';
          is_read: boolean;
          related_dispatch_id: string | null;
          related_truck_id: string | null;
          created_at: string;
        };
      };
      app_settings: {
        Row: {
          id: string;
          setting_key: string;
          setting_value: any;
          description: string | null;
          is_public: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      shift_logs: {
        Row: {
          id: string;
          user_id: string;
          started_at: string;
          ended_at: string | null;
          notes: string | null;
          created_at: string;
        };
      };
    };
  };
}
