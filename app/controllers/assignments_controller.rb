=begin
This file is part of SSID.

SSID is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

SSID is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with SSID.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'zip'

class AssignmentsController < ApplicationController
  before_action { |controller|
    if params[:course_id]
      @course = Course.find(params[:course_id])
      controller.send :authenticate_actions_for_role, UserCourseMembership::ROLE_TEACHING_ASSISTANT,
                                                      course: @course,
                                                      only: [ :index, :cluster_students, :new, :create, :edit, :update]
      controller.send :authenticate_actions_for_role, UserCourseMembership::ROLE_STUDENT,
                                                      course: @course,
                                                      only: [ ]
    end
  }

  # GET /courses/1/assignments
  def index
    @assignments = @course.assignments
    @empty_assignments = @course.empty_assignments
    @processing_assignments = @course.processing_assignments
    @processed_assignments = @course.processed_assignments
    @erroneous_assignments = @course.erroneous_assignments
  end
  
  # GET /assignments/1/cluster_students
  def cluster_students
    @assignment = Assignment.find(params["assignment_id"])
    respond_to do |format|
      format.json { 
        render json: @assignment.cluster_students.collect { |s| 
          { id: s.id, id_string: s.id_string } 
        } 
      }
    end
  end

  # GET /courses/1/assignments/1/log
  def show_log
    @assignment = Assignment.find(params[:assignment_id])
  end

  # GET /courses/1/assignments/1
  def show
    @assignment = Assignment.find(params[:id])
  end

  # GET /courses/1/assignments/new
  def new
    @assignment = Assignment.new
  end

  # POST /courses/1/assignments
  def create
    @assignment = Assignment.new { |a|
      a.title = params[:assignment]["title"]
      a.language = params[:assignment]["language"]
      a.min_match_length = params[:assignment]["min_match_length"]
      a.ngram_size = params[:assignment]["ngram_size"]
      a.course_id = @course.id
    }

    # Process file if @assignment is valid and file was uploaded
    if @assignment.valid?
     
      # Save assignment to obtain id
      return render action: "new" unless @assignment.save
      
      if !params[:assignment]["file"].nil?
        if (is_valid_zip?(params[:assignment]["file"].content_type, params[:assignment]["file"].path))
          self.start_upload(@assignment, params[:assignment]["file"])
          redirect_to course_assignments_url(@course), notice: 'Assignment was successfully created.'
        else
          if params[:assignment]["file"].nil?
            @assignment.errors.add :file, "is not selected for upload"
          elsif params[:assignment]["file"].content_type != "application/x-zip-compressed"
            @assignment.errors.add :file, "for upload must be a zip file"
          end
         return render action: "new"
        end
      else
        redirect_to course_assignments_url(@course), notice: 'Assignment was successfully created.'
      end
      
    else
      render action: "new"
    end
  end
  
  # PUT /courses/1/assignments/1
  def update
    @assignment = Assignment.find(params[:id])
    
    if !(params[:assignment].nil? or or !(is_valid_zip?(params[:assignment]["file"].content_type, params[:assignment]["file"].path)))
      self.start_upload(@assignment, params[:assignment]["file"])
      redirect_to course_assignments_url(@course), notice: 'File was successfully uploaded.'
    else
      if params[:assignment].nil?
          @assignment.errors.add :file, "is not selected for upload"
      elsif params[:assignment]["file"].content_type != "application/x-zip-compressed"
          @assignment.errors.add :file, "for upload must be a zip file"
      end
      return render action: "show" 
    end
  end

  # DELETE /courses/1/assignments/1
  def destroy
    @assignment = Assignment.find(params[:id])
    @assignment.destroy
  
    redirect_to course_assignments_url(@course), notice: 'Assignment was successfully deleted.'
  end
  
  def start_upload(assignment, file)
      require 'submissions_handler'

      # Process upload file
      submissions_path = SubmissionsHandler.process_upload(file, assignment)

      # Launch java program to process submissions
      SubmissionsHandler.process_submissions(submissions_path, assignment)
  end

  def is_valid_zip?(memeType, filePath)
    print filePath
    print memeType 
    if memeType == "application/x-zip-compressed" || 
      memeType == "application/zip-compressed" ||
      memeType == "application/zip"
      return true;
    else
      return is_opened_as_zip?(filePath)
    end
  end

  def is_opened_as_zip?(path)
    print path
    zip = Zip::File.open(path)
    true
  rescue StandardError
    false
  ensure
    zip.close if zip
  end
end


