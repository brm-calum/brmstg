import React from 'react';
import { Files } from 'lucide-react';
import { SortableFileList } from '../files/SortableFileList';
import { downloadFile } from '../../lib/utils/files';

interface FilesSummaryProps {
  inquiry: any;
}

export function FilesSummary({ inquiry }: FilesSummaryProps) {
  // Collect all files from the inquiry and responses
  const allFiles = [
    ...(inquiry.files || []),
    ...(inquiry.responses?.flatMap((r: any) => r.files || []) || [])
  ].map(file => ({
    id: file.id,
    name: file.file_name,
    size: file.file_size,
    type: file.mime_type,
    storage_path: file.storage_path,
    label: file.label,
    created_at: file.created_at,
   // comments: 0 // Add comment count when available*/
  }));

  if (allFiles.length === 0) {
    return (
      <div className="text-center py-8 text-gray-500">
        <Files className="h-12 w-12 mx-auto mb-4 text-gray-400" />
        <p>No files have been shared in this conversation</p>
      </div>
    );
  }

  return (
    <SortableFileList
      files={allFiles}
      onDownload={downloadFile}
      onUpdateLabel={async (id: string, label: string) => {
        // Implement label update functionality
      }}
    />
  );
}