import React from 'react';
import { Check, FileIcon, Download } from 'lucide-react';
import { formatRelativeTime } from '../../lib/utils/dates';
import { FileDisplay } from '../files/FileDisplay';
import { downloadFile } from '../../lib/utils/files';

interface MessageBubbleProps {
  message: any;
  isOwn: boolean;
  showReadStatus: boolean;
}

export function MessageBubble({ message, isOwn, showReadStatus }: MessageBubbleProps) {
  return (
    <div className="max-w-[75%]">
      <div
        className={`relative px-3 py-2 ${
          isOwn 
            ? 'text-gray-900' 
            : 'text-gray-900'
        }`}
      >
        <p className="whitespace-pre-wrap text-sm">{message.message}</p>

        {message.files?.length > 0 && (
          <div className="mt-2 space-y-1">
            {message.files.map((file: any) => (
              <FileDisplay
                key={file.id}
                file={file}
                onDownload={downloadFile}
              />
            ))}
          </div>
        )}

        <div className="mt-1 flex items-center justify-end space-x-1">
          <span className="text-[10px] text-gray-500">
            {formatRelativeTime(message.created_at)}
          </span>
          {isOwn && (
            <div className="flex">
              <Check className={`h-3 w-3 ${message.read ? 'text-green-500' : 'text-gray-400'}`} />
              <Check className={`h-3 w-3 -ml-1.5 ${message.read ? 'text-green-500' : 'text-gray-400'}`} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}