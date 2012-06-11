ActiveAdmin.register ImageUpload do

  actions :show, :index, :new, :create
  action_item({ :only => :show, :if => proc{ image_upload.status == ImageUpload::Status::NEW } }) do
    link_to "Process", process_upload_admin_image_upload_path
  end

  # prototype had this:
  index do
    column "Name", :sortable => :name do |iu|
      link_to iu.name, admin_image_upload_path(iu)
    end
    column :upload_path
    column :created_at
  end
  
  show :title => :name do |ad|
    attributes_table do
      row :name
      row :upload_path
      row :status
      row :working_dir
      row :created_at
    end

    h3 "Logs"
    table_for image_upload.image_upload_log do
      column("File") do 
        |lf| link_to lf.file, admin_image_upload_log_path(lf) 
      end
      column("Created") do 
        |lf| lf.created_at 
      end
      column("Last Updated") do 
        |lf| lf.updated_at 
      end
    end
    
    h3 "Directories" 
    table_for image_upload.image_dir do
      column("Name") do |dir| 
        link_to dir.name, admin_image_dir_path(dir) 
      end
      column("Path") { |dir| dir.path }
    end
  end


  member_action :process_upload  do    
      @image_upload = ImageUpload.find(params[:id])
      @image_upload.process_upload
      redirect_to admin_image_upload_path
  end


# docs has this:
#    form do |f|
#      f.inputs "Details" do
#        f.input :title
#        f.input :published_at, :label => "Publish Post At"
#        f.input :category
#      end
#      f.inputs "Content" do
#        f.input :body
#      end
#      f.buttons
#    end


  form do |f|
    f.inputs "Image Upload" do
      f.input :name
      f.input :upload_path
      f.buttons
    end
  end
  
  
end
