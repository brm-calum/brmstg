interface ConversationStatusProps {
  status: string;
}

export function ConversationStatus({ status }: ConversationStatusProps) {
  const styles = status === 'pending'
    ? 'bg-amber-100 text-amber-800 border border-amber-200'
    : 'bg-green-100 text-green-800 border border-green-200';

  return (
    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${styles}`}>
      {status}
    </span>
  );
}