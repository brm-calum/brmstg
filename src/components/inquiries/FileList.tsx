import React from 'react';
import { FileIcon, Trash2, Download } from 'lucide-react';

interface FileInfo {
  id: string;
  name: string;
  size: number;
  type: string;
}

interface FileListProps {
  files: FileInfo[];
  onDelete?: (index: number) => void;
  onDownload?: (id: string) => void;
  className?: string;
}

export function FileList({ files, onDelete, onDownload, className = '' }: FileListProps) {
  const formatSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  if (files.length === 0) return null;

  return (
    <div className={`space-y-2 ${className}`}>
      {files.map((file, index) => (
        <div
          key={file.id}
          className="flex items-center justify-between p-2 rounded-lg border border-gray-200 bg-gray-50"
        >
          <div className="flex items-center space-x-3">
            <FileIcon className="h-5 w-5 text-gray-400" />
            <div>
              <p className="text-sm font-medium text-gray-900">{file.name}</p>
              <p className="text-xs text-gray-500">{formatSize(file.size)}</p>
            </div>
          </div>
          
          <div className="flex items-center space-x-2">
            {onDownload && (
              <button
                onClick={() => onDownload(file.id)}
                className="p-1 text-gray-400 hover:text-gray-500"
              >
                <Download className="h-4 w-4" />
              </button>
            )}
            {onDelete && (
              <button
                onClick={() => onDelete(index)}
                className="p-1 text-gray-400 hover:text-red-500"
              >
                <Trash2 className="h-4 w-4" />
              </button>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}