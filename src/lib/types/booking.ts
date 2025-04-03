export interface Booking {
  id: string;
  status: 'active' | 'completed' | 'cancelled';
  start_date: string;
  end_date: string;
  total_cost_cents: number;
  created_at: string;
  warehouse: {
    id: string;
    name: string;
    address: string;
    city: string;
    country: string;
  };
  trader: {
    id: string;
    first_name: string;
    last_name: string;
    email: string;
  };
  warehouse_owner: {
    id: string;
    first_name: string;
    last_name: string;
    email: string;
  };
  spaces: Array<{
    space_type: string;
    size_m2: number;
    price_per_m2_cents: number;
  }>;
  services?: Array<{
    name: string;
    quantity: number;
    pricing_type: string;
    price_per_hour_cents?: number;
    price_per_unit_cents?: number;
    unit_type?: string;
  }>;
}

export interface BookingMessage {
  id: string;
  booking_id: string;
  sender_id: string;
  message: string;
  is_read: boolean;
  created_at: string;
  sender_info: {
    first_name: string;
    last_name: string;
    is_admin: boolean;
  };
}