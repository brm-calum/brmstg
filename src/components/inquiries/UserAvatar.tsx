interface UserAvatarProps {
  firstName: string;
  lastName: string;
  isOnline?: boolean;
}

export function UserAvatar({ firstName, lastName, isOnline }: UserAvatarProps) {
  return (
    <div className="flex-shrink-0 relative">
      <div className="h-12 w-12 rounded-full bg-teal-100 flex items-center justify-center text-teal-700 font-medium">
        {firstName.charAt(0)}
        {lastName.charAt(0)}
      </div>
      {isOnline && (
        <span className="absolute bottom-0 right-0 block h-3 w-3 rounded-full ring-2 ring-white bg-green-400" />
      )}
    </div>
  );
}