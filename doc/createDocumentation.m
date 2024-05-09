function createDocumentation(inputFolderPath)
    % Validate input folder path
    if ~isfolder(inputFolderPath)
        error('Input path is not a valid folder: %s', inputFolderPath);
    end

    % Get all items in the input directory
    items = dir(inputFolderPath);
    % Filter for directories starting with '@'
    atFolders = items([items.isdir] & startsWith({items.name}, '@'));
    
    % Iterate over each @folder
    for i = 1:length(atFolders)
        folderPath = fullfile(inputFolderPath, atFolders(i).name);
        classFiles = dir(fullfile(folderPath, '*.m'));
        
        % Create Readme.md file in the @folder
        readmeFilePath = fullfile(folderPath, 'Readme.md');
        fid = fopen(readmeFilePath, 'w');
        
        % Process each .m file in the @folder
        for j = 1:length(classFiles)
            classFilePath = fullfile(folderPath, classFiles(j).name);
            
            try
                % Extract comments and write to Markdown
                markdownText = extractAndWriteComments(classFilePath);
                fprintf(fid, '%s\n', markdownText);
            catch ME
                warning('Failed to process %s: %s', classFilePath, ME.message);
            end
        end
        
        fclose(fid);
    end
    
    disp('Completed documentation for all classes.');
end

function markdownText = extractAndWriteComments(inputFilePath)
    % Open the MATLAB .m file
    fid = fopen(inputFilePath, 'r');
    if fid == -1
        error('File cannot be opened: %s', inputFilePath);
    end
    
    % Read the entire file into memory
    fileContents = fread(fid, '*char')';
    fclose(fid);
    
    % Regular expression to extract the first significant comment block
    commentPattern = '(\s*%[^\n]*\n)+';
    [startIndex, endIndex] = regexp(fileContents, commentPattern, 'once');
    
    if isempty(startIndex)
        error('No initial comment block found.');
    end
    
    % Extract the comment block
    commentBlock = fileContents(startIndex:endIndex);
    
    % Split the comment block into lines and remove MATLAB comment symbols
    commentLines = strsplit(commentBlock, '\n');
    commentLines = cellfun(@(x) strtrim(strrep(x, '%', '')), commentLines, 'UniformOutput', false);
    commentLines = commentLines(~cellfun('isempty', commentLines)); % Remove empty lines
    
    % Format the first non-empty line as a header
    if ~isempty(commentLines)
        commentLines{1} = ['# ' commentLines{1}];
        markdownText = strjoin(commentLines, '\n');
    else
        markdownText = '';
    end
    
    return;
end
